# v0.3.15

## 新增 | New
- 任务组的任务列表改成可以新增和拖动排序的列表（配合 OAS 的任务组改动）
- 发布适用于 Android 的通用 APK，并支持应用内下载与安装更新

## 改进 | Improved
- 任务组里已经加过的任务不再出现在「新增任务」里，并显示已选数量与上限
- Android 可连接局域网 HTTP OAS 服务，窄屏设置项改为纵向布局
- 应用更新源改为本仓库的 GitHub Release
- Android 发布版改用独立签名密钥，移除仓库中的旧密钥和口令说明

## 修复 | Fixed
- 修复 `ArgsController.loadModel` 未将参数转为 `ArgumentModel` 的问题

## 说明 | Notes
- 安卓首次使用时，在设置页填写手机可访问的 OAS 服务地址
- 任务组列表功能需要配合带 `task_list` 的 OAS 服务端版本
