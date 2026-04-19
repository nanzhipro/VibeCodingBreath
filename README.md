# VibeCodingBreath

macOS 菜单栏常驻的“静止呼吸灯”小工具：检测到键鼠在 5 秒内无操作时，在屏幕中央渲染一圈柔和的呼吸光环，引导深呼吸；一旦有任何输入立刻淡出，全屏 / 演示场景自动避让。

- Bundle ID: `pro.nanzhi.VibeCodingBreath`
- 平台：macOS 14+ · Apple Silicon / Intel
- 构建：Swift 5.10 · SwiftPM · AppKit + SwiftUI
- 许可：见仓库根

## 快速开始

```bash
swift test                              # 23 个 XCTest
./Scripts/build-app.sh debug            # 组装可运行的 .app
open .build/debug/VibeCodingBreath.app
```

## 发布流程

```bash
./Scripts/release.sh --version 0.1.0 --keychain-profile <notary-profile>
# 产物：dist/VibeCodingBreath-<version>-<arch>.dmg
```

完整发布管线（测试 → 编译 → 组 .app → Developer ID 签名 → DMG → 公证 + staple）见 [Scripts/release.sh](Scripts/release.sh)。

## 文档

- 产品需求：[docs/PRD.md](docs/PRD.md)
- 技术方案：[docs/TECH_PLAN.md](docs/TECH_PLAN.md)
- 测试计划：[docs/TEST_PLAN.md](docs/TEST_PLAN.md)

## 一键复刻

本仓库完全由一条 Claude Code 提示词生成。完整 prompt 见 [docs/PROMPT.md](docs/PROMPT.md)。

```bash
claude --dangerously-skip-permissions -p "$(cat docs/PROMPT.md)"
```
