# Hysteria 2 一键安装脚本

基于 [Hysteria 2](https://github.com/apernet/hysteria) 官方文档 (v2.7.x) 更新的一键安装脚本。

原始脚本来自 [Misaka-blog](https://github.com/Misaka-blog/hysteria-install)，本版本进行了全面更新以兼容最新版本。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/hysteria-install/main/hy2/hysteria.sh)
```

> ⚠️ 请将 `USERNAME` 替换为你的 GitHub 用户名。

## 功能特点

- ✅ 使用官方 `get.hy2.sh` 脚本安装 Hysteria 2 最新版
- ✅ 三种证书方式：自签证书 / ACME 自动申请 / 自定义路径
- ✅ 支持单端口和端口跳跃模式
- ✅ 自动生成客户端配置（YAML / JSON / Clash Meta）
- ✅ 自签证书自动计算 `pinSHA256` 指纹
- ✅ 同时支持 SOCKS5 和 HTTP 代理
- ✅ 一键更新 Hysteria 2 内核
- ✅ 查看服务状态和运行日志
- ✅ 支持 Debian / Ubuntu / CentOS / Fedora / Arch Linux

## 菜单功能

| 选项 | 功能 |
|------|------|
| 1 | 安装 Hysteria 2 |
| 2 | 卸载 Hysteria 2 |
| 3 | 关闭 / 开启 / 重启 Hysteria 2 |
| 4 | 修改配置 (端口 / 密码 / 证书 / 伪装网站) |
| 5 | 显示配置文件 |
| 6 | 更新 Hysteria 2 内核 |
| 7 | 查看服务状态 |
| 8 | 查看运行日志 |

## 相关链接

- [Hysteria 2 官方项目](https://github.com/apernet/hysteria)
- [Hysteria 2 中文文档](https://v2.hysteria.network/zh/)

## 许可证

MIT License
