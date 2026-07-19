const invoke = window.__TAURI__?.core?.invoke;

const player = document.querySelector("#player");
const fileInput = document.querySelector("#fileInput");
const fileName = document.querySelector("#fileName");
const playPause = document.querySelector("#playPause");
const seek = document.querySelector("#seek");
const currentTime = document.querySelector("#currentTime");
const duration = document.querySelector("#duration");
const volume = document.querySelector("#volume");
const volumeValue = document.querySelector("#volumeValue");
const mute = document.querySelector("#mute");
const playbackRate = document.querySelector("#playbackRate");
const playbackRateValue = document.querySelector("#playbackRateValue");
const fullscreen = document.querySelector("#fullscreen");
const closeFullscreen = document.querySelector("#closeFullscreen");
const playerFrame = document.querySelector("#playerFrame");

const PLAYBACK_RATES = [0.25, 0.5, 1, 1.5, 2];

let config = {
  volume: 0.8,
  muted: false,
  playbackRate: 1
};
let activeUrl = null;
let seeking = false;

const formatTime = (seconds) => {
  if (!Number.isFinite(seconds)) return "00:00";
  const total = Math.max(0, Math.floor(seconds));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) {
    return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  }
  return `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
};

const saveConfig = async () => {
  if (!invoke) return;
  try {
    await invoke("save_config", { config });
  } catch (error) {
    console.error("config save failed", error);
  }
};

const loadConfig = async () => {
  if (!invoke) return;
  try {
    config = { ...config, ...(await invoke("load_config")) };
  } catch (error) {
    console.error("config load failed", error);
  }
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const normalizedPlaybackRate = (rate) => {
  const numericRate = Number(rate);
  return PLAYBACK_RATES.includes(numericRate) ? numericRate : 1;
};

const formatPlaybackRate = (rate) => {
  if (rate === 0.25) return "0.25×";
  return `${rate.toFixed(1)}×`;
};

const updateVolumeUi = () => {
  volume.value = String(player.volume);
  volumeValue.textContent = String(Math.round(player.volume * 100));
  mute.textContent = player.muted || player.volume === 0 ? "🔇" : "🔊";
};

const updatePlaybackRateUi = () => {
  const rate = normalizedPlaybackRate(player.playbackRate);
  playbackRate.value = String(PLAYBACK_RATES.indexOf(rate));
  playbackRateValue.textContent = formatPlaybackRate(rate);
};

const applyConfig = () => {
  player.volume = clamp(Number(config.volume ?? 0.8), 0, 1);
  player.muted = Boolean(config.muted);
  player.playbackRate = normalizedPlaybackRate(config.playbackRate);
  updateVolumeUi();
  updatePlaybackRateUi();
};

const updatePlayButton = () => {
  playPause.textContent = player.paused ? "▶" : "⏸";
};

const togglePlayback = () => {
  if (!player.getAttribute("src")) return;
  if (player.paused) {
    player.play().catch(() => updatePlayButton());
  } else {
    player.pause();
  }
};

const seekBy = (seconds) => {
  if (!Number.isFinite(player.duration) || player.duration <= 0) return;
  player.currentTime = clamp(player.currentTime + seconds, 0, player.duration);
};

const adjustVolume = (step) => {
  const currentPercent = Math.round(player.volume * 100);
  player.volume = clamp(currentPercent + step, 0, 100) / 100;
  player.muted = false;
  config.volume = player.volume;
  config.muted = false;
  updateVolumeUi();
  saveConfig();
};

const updateSeek = () => {
  duration.textContent = formatTime(player.duration);
  currentTime.textContent = formatTime(player.currentTime);
  if (!seeking && Number.isFinite(player.duration) && player.duration > 0) {
    seek.value = String(Math.round((player.currentTime / player.duration) * 1000));
  }
};

const updateFullscreenUi = () => {
  const isFullscreen = document.fullscreenElement === playerFrame;
  playerFrame.classList.toggle("is-fullscreen", isFullscreen);
  fullscreen.textContent = isFullscreen ? "↙" : "⛶";
  fullscreen.title = isFullscreen ? "通常表示へ戻る" : "フルスクリーン";
  fullscreen.setAttribute("aria-label", fullscreen.title);
};

fileInput.addEventListener("change", () => {
  const file = fileInput.files?.[0];
  if (!file) return;
  if (activeUrl) URL.revokeObjectURL(activeUrl);
  activeUrl = URL.createObjectURL(file);
  player.src = activeUrl;
  player.controls = false;
  player.load();
  fileName.textContent = file.name;
  player.play().catch(() => updatePlayButton());
});

playPause.addEventListener("click", () => {
  if (!player.src) {
    fileInput.click();
    return;
  }
  togglePlayback();
});

seek.addEventListener("input", () => {
  seeking = true;
  if (Number.isFinite(player.duration) && player.duration > 0) {
    currentTime.textContent = formatTime((Number(seek.value) / 1000) * player.duration);
  }
});

seek.addEventListener("change", () => {
  if (Number.isFinite(player.duration) && player.duration > 0) {
    player.currentTime = (Number(seek.value) / 1000) * player.duration;
  }
  seeking = false;
});

volume.addEventListener("input", () => {
  player.volume = Number(volume.value);
  if (player.volume > 0) player.muted = false;
  config.volume = player.volume;
  config.muted = player.muted;
  updateVolumeUi();
  saveConfig();
});

mute.addEventListener("click", () => {
  player.muted = !player.muted;
  config.muted = player.muted;
  updateVolumeUi();
  saveConfig();
});

playbackRate.addEventListener("input", () => {
  const rate = PLAYBACK_RATES[Number(playbackRate.value)] ?? 1;
  player.playbackRate = rate;
  config.playbackRate = rate;
  updatePlaybackRateUi();
  saveConfig();
});

fullscreen.addEventListener("click", () => {
  if (document.fullscreenElement === playerFrame) {
    document.exitFullscreen();
  } else {
    playerFrame.requestFullscreen();
  }
});

closeFullscreen.addEventListener("click", () => {
  if (document.fullscreenElement) {
    document.exitFullscreen();
  }
});

document.addEventListener("keydown", (event) => {
  if (event.altKey || event.ctrlKey || event.metaKey) return;

  switch (event.key) {
    case "ArrowRight":
      event.preventDefault();
      seekBy(5);
      break;
    case "ArrowLeft":
      event.preventDefault();
      seekBy(-5);
      break;
    case "ArrowUp":
      event.preventDefault();
      adjustVolume(1);
      break;
    case "ArrowDown":
      event.preventDefault();
      adjustVolume(-1);
      break;
    case " ":
    case "Spacebar":
      event.preventDefault();
      togglePlayback();
      break;
    default:
      break;
  }
});

document.addEventListener("fullscreenchange", updateFullscreenUi);

player.addEventListener("play", updatePlayButton);
player.addEventListener("pause", updatePlayButton);
player.addEventListener("volumechange", updateVolumeUi);
player.addEventListener("ratechange", updatePlaybackRateUi);
player.addEventListener("loadedmetadata", updateSeek);
player.addEventListener("timeupdate", updateSeek);
player.addEventListener("ended", updatePlayButton);

await loadConfig();
applyConfig();
updatePlayButton();
updateSeek();
updateFullscreenUi();
