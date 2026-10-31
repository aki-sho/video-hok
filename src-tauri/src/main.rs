use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    io::Read,
    path::{Path, PathBuf},
};
use tauri::{State, WebviewUrl, WebviewWindowBuilder};

const DISPLAY_NAME: &str = "Video HOK";
const ENGLISH_NAME: &str = env!("CARGO_PKG_NAME");
const PORTABLE_DATA_SUFFIX: &str = "PortableData";
const PLAYBACK_RATES: [f64; 5] = [0.25, 0.5, 1.0, 1.5, 2.0];
const MAX_CONFIG_BYTES: u64 = 4096;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
struct AppConfig {
    volume: f64,
    muted: bool,
    #[serde(rename = "playbackRate")]
    playback_rate: f64,
}

impl AppConfig {
    fn validate(&self) -> Result<(), String> {
        if !self.volume.is_finite() || !(0.0..=1.0).contains(&self.volume) {
            return Err("音量は0から1の有限値で指定してください".to_string());
        }
        if !PLAYBACK_RATES.contains(&self.playback_rate) {
            return Err("対応していない再生速度です".to_string());
        }
        Ok(())
    }
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            volume: 0.8,
            muted: false,
            playback_rate: 1.0,
        }
    }
}

#[derive(Debug, Clone)]
struct AppPaths {
    root: PathBuf,
    portable: bool,
}

impl AppPaths {
    fn detect() -> Result<Self, String> {
        if cfg!(feature = "portable") {
            let exe = env::current_exe().map_err(|error| error.to_string())?;
            let exe_dir = exe
                .parent()
                .ok_or_else(|| "実行ファイルのフォルダを取得できませんでした".to_string())?;
            return Ok(Self {
                root: exe_dir.join(format!("{ENGLISH_NAME}-{PORTABLE_DATA_SUFFIX}")),
                portable: true,
            });
        }

        let app_data = env::var_os("APPDATA")
            .ok_or_else(|| "AppDataフォルダを取得できませんでした".to_string())?;
        Ok(Self {
            root: PathBuf::from(app_data).join(ENGLISH_NAME),
            portable: false,
        })
    }

    fn prepare(&self) -> Result<(), String> {
        for directory in [
            self.root.clone(),
            self.root.join("data"),
            self.root.join("logs"),
            self.root.join("cache"),
            self.root.join("temp"),
            self.root.join("WebView"),
        ] {
            fs::create_dir_all(directory).map_err(|error| error.to_string())?;
        }
        Ok(())
    }

    fn config_file(&self) -> PathBuf {
        self.root.join("config.json")
    }

    fn webview_data(&self) -> PathBuf {
        self.root.join("WebView")
    }

    fn temp_dir(&self) -> PathBuf {
        self.root.join("temp")
    }
}

fn configure_portable_environment(paths: &AppPaths) {
    if !paths.portable {
        return;
    }

    let temp_dir = paths.temp_dir();
    // This runs before Tauri starts worker threads, so changing process-local
    // temporary-directory variables cannot race with another app thread.
    unsafe {
        env::set_var("TEMP", &temp_dir);
        env::set_var("TMP", &temp_dir);
    }
}

fn write_config(path: &Path, config: &AppConfig) -> Result<(), String> {
    config.validate()?;
    let text = serde_json::to_string_pretty(config).map_err(|error| error.to_string())?;
    fs::write(path, format!("{text}\n")).map_err(|error| error.to_string())
}

#[tauri::command]
fn load_config(paths: State<'_, AppPaths>) -> Result<AppConfig, String> {
    let path = paths.config_file();
    if !path.exists() {
        let config = AppConfig::default();
        write_config(&path, &config)?;
        return Ok(config);
    }

    read_config(&path)
}

fn read_config(path: &Path) -> Result<AppConfig, String> {
    let mut text = String::new();
    fs::File::open(path)
        .map_err(|error| error.to_string())?
        .take(MAX_CONFIG_BYTES + 1)
        .read_to_string(&mut text)
        .map_err(|error| error.to_string())?;
    if text.len() as u64 > MAX_CONFIG_BYTES {
        return Err("設定ファイルが大きすぎます".to_string());
    }
    let config: AppConfig = serde_json::from_str(&text).map_err(|error| error.to_string())?;
    config.validate()?;
    Ok(config)
}

#[tauri::command]
fn save_config(paths: State<'_, AppPaths>, config: AppConfig) -> Result<(), String> {
    write_config(&paths.config_file(), &config)
}

fn run() -> Result<(), String> {
    let paths = AppPaths::detect()?;
    paths.prepare()?;
    configure_portable_environment(&paths);
    let webview_data = paths.webview_data();

    tauri::Builder::default()
        .manage(paths)
        .setup(move |app| {
            let mut window =
                WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                    .title(DISPLAY_NAME)
                    .inner_size(960.0, 620.0)
                    .min_inner_size(360.0, 420.0)
                    .resizable(true)
                    .data_directory(webview_data.clone());

            if let Some(icon) = app.default_window_icon() {
                window = window.icon(icon.clone())?;
            }

            window.build()?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![load_config, save_config])
        .run(tauri::generate_context!())
        .map_err(|error| error.to_string())
}

fn main() {
    if let Err(error) = run() {
        eprintln!("video-hok startup failed: {error}");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use tauri::ipc::Origin;

    static NEXT_TEST: AtomicUsize = AtomicUsize::new(0);

    struct TestFile(PathBuf);

    impl TestFile {
        fn new() -> Self {
            Self(env::temp_dir().join(format!(
                "video-hok-config-{}-{}.json",
                std::process::id(),
                NEXT_TEST.fetch_add(1, Ordering::Relaxed)
            )))
        }
    }

    impl Drop for TestFile {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.0);
        }
    }

    #[test]
    fn accepts_supported_settings_and_volume_boundaries() {
        for volume in [0.0, 0.8, 1.0] {
            for playback_rate in PLAYBACK_RATES {
                assert!(AppConfig {
                    volume,
                    playback_rate,
                    muted: true
                }
                .validate()
                .is_ok());
            }
        }
    }

    #[test]
    fn rejects_invalid_numbers_and_unsupported_playback_rates() {
        for volume in [-0.01, 1.01, f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
            assert!(AppConfig {
                volume,
                ..AppConfig::default()
            }
            .validate()
            .is_err());
        }
        for playback_rate in [0.0, -1.0, 0.75, 3.0, f64::NAN, f64::INFINITY] {
            assert!(AppConfig {
                playback_rate,
                ..AppConfig::default()
            }
            .validate()
            .is_err());
        }
    }

    #[test]
    fn invalid_save_preserves_existing_settings() {
        let file = TestFile::new();
        write_config(&file.0, &AppConfig::default()).unwrap();
        let original = fs::read(&file.0).unwrap();
        assert!(write_config(
            &file.0,
            &AppConfig {
                volume: 5.0,
                ..AppConfig::default()
            }
        )
        .is_err());
        assert_eq!(fs::read(&file.0).unwrap(), original);
    }

    #[test]
    fn rejects_invalid_or_oversized_settings_on_load() {
        let file = TestFile::new();
        for text in [
            r#"{"volume":2}"#.to_string(),
            r#"{"playbackRate":100}"#.to_string(),
            r#"{"muted":"yes"}"#.to_string(),
            "{".to_string(),
            " ".repeat(MAX_CONFIG_BYTES as usize + 1),
        ] {
            fs::write(&file.0, text).unwrap();
            assert!(read_config(&file.0).is_err());
        }
        fs::write(&file.0, "{}").unwrap();
        assert_eq!(read_config(&file.0).unwrap().volume, 0.8);
    }

    #[test]
    fn config_commands_are_local_and_main_window_only() {
        // Use the actual compiled ACL, rather than a separate test policy.
        let mut context: tauri::Context<tauri::Wry> = tauri::generate_context!();
        let authority = context.runtime_authority_mut();
        let remote = Origin::Remote {
            url: "https://example.com".parse().unwrap(),
        };
        for command in ["load_config", "save_config"] {
            assert!(authority
                .resolve_access(command, "main", "main", &Origin::Local)
                .is_some());
            assert!(authority
                .resolve_access(command, "other", "other", &Origin::Local)
                .is_none());
            assert!(authority
                .resolve_access(command, "main", "main", &remote)
                .is_none());
        }
        assert!(authority
            .resolve_access("plugin:fs|read_file", "main", "main", &Origin::Local)
            .is_none());
    }
}
