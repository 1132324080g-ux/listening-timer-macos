# 聆听计时

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

“聆听计时”是一款 macOS 26+ 菜单栏应用。它只统计用户选中的音频应用通过蓝牙或有线耳机播放的时长，并保留本机统计历史。

## 下载

从 [GitHub Releases](https://github.com/1132324080g-ux/listening-timer-macos/releases/latest) 下载最新的 Universal 2 DMG。

## 主要功能

- 自动识别蓝牙、蓝牙 LE、3.5 mm、USB、雷雳和 FireWire 音频输出。
- 按每副耳机的设备 UID 独立累计聆听时长；切换耳机时会结束旧会话并建立新记录。
- 可给外置耳机或声卡设置自定义名称，名称会同步用于概览、历史、菜单栏和 CSV 导出。
- 从当前音频进程中勾选任意音频应用，不需要 Apple Events 或媒体库权限。
- 静音、音量为零、断开耳机或播放器停止时结束计时。
- 菜单栏实时显示本次聆听时长，另有弹出面板和完整统计窗口。
- 主窗口支持侧边栏/顶部导航、三种概览密度，以及组件显示隐藏和拖动排序。
- 实时卡片与菜单栏可同时展示本次、今日和全部累计时长。
- 提供今日、本周、本月和全部统计、七日图表、来源分布及历史会话。
- 永久保存本地历史，支持 CSV 导出与清空。
- 通过 `SMAppService` 管理登录时静默启动。
- 原生液态玻璃界面，自适应浅色/深色、高对比度与减少动态效果。
- 主窗口使用应用内关闭、最小化和全屏按钮，菜单栏弹窗采用真实背景毛玻璃。
- 首次启动提供三步式引导，集中完成来源、设备与登录启动设置。

## 构建

需要 macOS 26、Swift 6.2+ 和 Command Line Tools 或完整 Xcode。

```zsh
chmod +x Scripts/build-app.sh
./Scripts/build-app.sh
```

构建脚本会先运行不依赖 XCTest 的核心自检，然后生成 Universal 2 应用和 DMG：

```text
dist/聆听计时.app
dist/聆听计时-1.2.0-universal.dmg
```

当前产物使用 ad-hoc 签名，没有 Developer ID 公证。首次打开时可能需要在 Finder 中右键应用并选择“打开”，或在“系统设置 > 隐私与安全性”中允许运行。

## 安装与开机启动

1. 打开 DMG，将“聆听计时”拖入“应用程序”。
2. 第一次运行完成音频来源和设备设置。
3. 在向导或设置中开启“登录时静默启动”。
4. 如果 macOS 要求批准，前往“系统设置 > 通用 > 登录项与扩展”允许应用。

应用默认以菜单栏工具方式启动。打开主窗口时会显示 Dock 图标，并可将窗口最小化到 Dock；关闭统计窗口后应用会回到仅菜单栏驻留，继续记录。选择“暂停记录”或退出应用才会停止计时。

## 数据与隐私

数据位于：

```text
~/Library/Application Support/com.lazycanary.ListeningTimer/
```

应用不会联网、录制音频、读取歌曲元数据或媒体库。CSV 只包含本地会话的时间、来源 bundle ID、设备名称和传输类型。

## 测试

在当前只有 Command Line Tools 的环境中，可以运行：

```zsh
swift run --disable-sandbox --scratch-path .build CoreSelfTests
```

`Tests/ListeningCoreTests` 使用 Swift Testing，完整 Xcode 工具链会自动提供相应测试宏。纯 Command Line Tools 缺少 SwiftUI Testing 插件，因此标准 `swift test` 应优先在完整 Xcode 环境中执行。

## 已知边界

- macOS 不公开“耳机是否实际戴在头上”的信息，统计以“选定播放器正在向蓝牙或有线音频设备输出”为准。
- 部分外置声卡不提供系统音量控制。此时开启“静音时停止计时”也无法读取静音状态，应用会退化为按播放活动计时。
- 有些常驻 USB DAC 无法判断其后端是否真的连接了耳机；如果自动识别不正确，可在设置中调整设备。
- 3.5 mm 模拟耳机不向 macOS 提供品牌或型号。系统只能判断插孔是否连接，无法自动区分插在同一接口上的不同耳机。
- 蓝牙耳机的左右耳通常作为同一副配对设备报告，因此独立累计以配对设备的 UID/名称为单位，而不是分左右耳统计。
- 多个选定播放器同时播放时，总时长只计算一次，来源分布中的各播放器时长可以重叠。

## 许可证

本项目采用 [MIT License](LICENSE)。Copyright © 2026 LazyCanary。
