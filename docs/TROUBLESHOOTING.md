# Troubleshooting

## There is no microphone permission prompt

macOS usually prompts only when a choice is needed. Check **System Settings → Privacy & Security → Microphone → AirMic**, allow access, then restart AirMic. The public source uses bundle ID `local.airmic.app`; a locally renamed prototype may have separate permission state. Do not delete system privacy databases to fix this.

## The stem does nothing

Confirm that AirMic says **AirPods 버튼 감지 중**, the AirPods are connected, and you used their configured mute gesture. Check the current default input supports a writable mute property with `--check`. Other calling apps can take over AirPods controls; try without those apps, then test your intended combination. Include the environment and reproduction in a bug report.

## The UI says muted, but another app hears audio

AirMic controls the current default input device, not every input. Check the other app's selected microphone. Its own mute button may remain unchanged. Verify audio behavior in that app; hardware-property readback is not an end-to-end silence test.

## “음소거 제어 불가” / unsupported input

The selected microphone does not expose the writable master input mute control this implementation uses. Choose a supported input. AirMic does not install a virtual driver or silently fall back to changing input volume.

## Bluetooth quality or battery use changes

Listening keeps input I/O active even though buffers are unread. Stop button detection from the menu when you do not need it, or quit normally. No specific battery-use claim has been measured.

## Mute state did not restore

Reconnect the affected input, launch AirMic, and quit with **종료 (원래 마이크 상태 복원)**. If a connected device fails restoration, the app offers to cancel quitting. Disconnected devices are retained for a later retry. If recovery still fails, set the microphone's mute state through its own controls and report the failure.

Do not remove `OriginalMuteStates` until you have restored the intended state. Normal quit restores the value from before AirMic's first change, which may differ from changes another app made later.

## The build fails

Install Apple's Command Line Tools or use an Xcode installation whose license you have accepted yourself. The build prefers standalone tools unless `DEVELOPER_DIR` is set. Share the error, toolchain version, and commit; remove personal paths. The source targets macOS 14+ at runtime, even when an older SDK can compile it.

## Korean quick reference

- 권한 요청이 안 뜨면 시스템 설정의 마이크 권한에서 AirMic을 확인하세요.
- 버튼 감지가 켜져 있는지, 기본 입력이 음소거 제어를 지원하는지 확인하세요.
- 통화 앱이 다른 입력 장치를 쓰면 AirMic의 음소거가 적용되지 않습니다.
- 복원 실패 시 장치를 다시 연결하고 AirMic을 정상 종료하세요. 복원 전 설정을 지우지 마세요.
