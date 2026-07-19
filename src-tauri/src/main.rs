use serde::{Deserialize, Serialize};
use std::{
    env, fs,
    path::{Path, PathBuf},
};
use tauri::{State, WebviewUrl, WebviewWindowBuilder};

const DISPLAY_NAME: &str = "Video HOK";
const ENGLISH_NAME: &str = env!("CARGO_PKG_NAME");
const PORTABLE_DATA_SUFFIX: &str = "PortableData";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
struct AppConfig {
    volume: f64,
    muted: bool,
    #[serde(rename = "playbackRate")]
    playback_rate: f64,
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

    let text = fs::read_to_string(path).map_err(|error| error.to_string())?;
    serde_json::from_str(&text).map_err(|error| error.to_string())
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
