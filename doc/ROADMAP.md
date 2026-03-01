# Wrap - 后续迭代路线图

## Phase 1: MVP（当前）
> 核心目标：能用密码连接 SSH 并获得完整终端体验

- [x] SwiftTerm 终端模拟器集成
- [x] swift-nio-ssh 密码认证
- [x] 服务器信息 CRUD（SwiftData）
- [x] Keychain 安全存储密码
- [x] 分组和搜索
- [x] 一键连接
- [x] 断开重连

---

## Phase 2: 安全增强

### 2.1 私钥认证
- 支持 RSA、Ed25519、ECDSA 私钥
- PEM 格式解析（可能需要 `swift-crypto` 辅助）
- 支持加密私钥（passphrase）
- 私钥导入：从文件选择器导入 / 粘贴内容
- 私钥存储在 Keychain 中

### 2.2 Host Key 验证
- 首次连接显示 host key fingerprint，用户确认后存储
- 后续连接自动校验，不匹配时警告
- Known hosts 存储（SwiftData 或文件）

### 2.3 生物识别
- Face ID / Touch ID 保护 App 启动
- 可选：单独保护特定服务器连接
- 使用 `LAContext` (LocalAuthentication framework)

---

## Phase 3: 多会话与效率

### 3.1 多会话支持
- 底部 Tab Bar 或横向滑动切换活跃会话
- 会话指示器显示活跃连接数
- 后台保持连接（在 App 切换到后台时短暂维持）

### 3.2 快捷命令 / Snippets
- 预存常用命令片段
- 长按发送到当前终端
- 支持变量替换（如 `${hostname}`）

### 3.3 终端定制
- 多主题支持（Solarized, Dracula, Monokai 等）
- 字体大小调整（捏合手势缩放）
- 自定义颜色方案

---

## Phase 4: 文件管理

### 4.1 SFTP 文件浏览器
- 浏览远程文件系统
- 上传/下载文件
- 文件预览（文本、图片）
- 与 iOS Files app 集成（FileProvider）

### 4.2 内置文本编辑器
- 简单的远程文件编辑（作为 vim 的补充）
- 语法高亮
- 保存时自动通过 SFTP 上传

---

## Phase 5: 高级网络

### 5.1 端口转发
- 本地端口转发（Local forwarding）
- 远程端口转发（Remote forwarding）
- 动态端口转发（SOCKS proxy）
- 转发状态可视化

### 5.2 Mosh 支持
- UDP-based 连接，更适合移动网络
- 本地回显，降低延迟感知
- 无缝网络切换（Wi-Fi ↔ 蜂窝）

### 5.3 Jump Host / ProxyJump
- 通过跳板机连接目标服务器
- 多跳链路配置
- 在 ServerConnection 模型中添加 proxyServer 字段

---

## Phase 6: 同步与协作

### 6.1 iCloud 同步
- 服务器配置跨设备同步（iPhone ↔ iPad）
- 使用 CloudKit 或 SwiftData + iCloud container
- 凭据通过 iCloud Keychain 同步

### 6.2 导入导出
- 导入 OpenSSH `~/.ssh/config` 格式
- 导出为标准格式
- 支持从其他 SSH 客户端迁移

### 6.3 共享连接
- 通过 AirDrop 或链接分享服务器配置（不含密码）
- 团队共享服务器列表

---

## Phase 7: iPad 增强

### 7.1 多窗口
- iPad 上支持 Split View / Slide Over
- 多窗口独立会话
- Stage Manager 支持

### 7.2 键盘快捷键
- 完整的快捷键系统（⌘+T 新建、⌘+W 关闭等）
- 快捷键可自定义
- 快捷键提示覆盖层

### 7.3 分屏终端
- 单窗口内水平/垂直分屏
- 类似 tmux 但原生 UI
- 拖拽调整分屏比例

---

## 技术债务 & 持续改进

- [ ] 单元测试覆盖核心服务（SSHService, KeychainService）
- [ ] UI 测试覆盖关键流程
- [ ] 错误日志收集和崩溃报告
- [ ] 性能优化：大量输出时的终端渲染性能
- [ ] 无障碍支持（VoiceOver, Dynamic Type）
- [ ] 国际化（中文/英文）
- [ ] App Store 上架准备（截图、描述、隐私政策）
