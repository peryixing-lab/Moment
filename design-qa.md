# “此刻”桌面卡片视觉与交互 QA

## 验收范围

- 2×2 设计源：`/Users/thousandmiles/.codex/generated_images/019f8d3e-e0d6-7ba2-8d56-60c725946848/call_9kAgp6VRw6lIwHRD0HnDAJXF.png`
- 2×4 设计源：`/Users/thousandmiles/.codex/generated_images/019f8d3e-e0d6-7ba2-8d56-60c725946848/call_8pQjl0cFXHPifU0sjbp2RZ8n.png`
- 4×4 设计源：`/Users/thousandmiles/.codex/generated_images/019f8d3e-e0d6-7ba2-8d56-60c725946848/call_VmD9iKMe8pcm2SJnIR8EnGmo.png`
- 实现截图：`qa/widget-2x2-state-full.png`、`qa/widget-2x4-state-full.png`、`qa/widget-4x4-state-full.png`
- 聚焦对比：`qa/widget-2x2-comparison.png`、`qa/widget-2x4-comparison.png`、`qa/widget-4x4-comparison.png`
- 运行环境：DevEco Studio Previewer，浅色模式
- 2×2：最小 132×132、默认 140×140、最大 152×152
- 2×4：最小 285×132、默认 300×140、最大 324×152
- 4×4：最小 285×293、默认 300×312、最大 324×340

预览状态使用图书馆 / 时间规则、14:18、数据结构 15:00、倒计时 42 分钟、25 分钟专注及两条任务。以上均为 Previewer 临时夹具，视觉验收后已经移除；正式卡片只消费应用绑定数据与资源回退值。

## 对比结论

- 2×2：场景标识、倒计时、课程与时间、紧凑操作按钮的层级和留白与设计稿一致，三种系统尺寸均无裁切。
- 2×4：完整场景标题、主事件、时间地点、主操作和切换入口保持同一阅读顺序；固定 150vp 主按钮避免最大规格中过度拉伸。
- 4×4：延续 2×4 主信息，并展示“今日重点”两条辅助内容；23fp 主数字与 16fp 单位在最大规格下完整显示“分钟”。
- 色彩、圆角、分割线、系统 Symbol 和字体均使用项目资源，不依赖预览位图。

## 迭代记录

### 迭代 1：尺寸与数据链路

- 初始配置只声明 2×4，新增 2×2、2×4、4×4 三种规格。
- 新增按 formId 持久化尺寸；创建和刷新卡片时按实际尺寸生成对应绑定数据。
- Previewer 无运行时 dimension 注入时曾落入 2×4；通过逐尺寸默认值完成视觉验收，正式运行仍以绑定数据为准。

### 迭代 2：布局校准

- 2×4 和 4×4 主按钮原先随容器拉伸，改为固定 150vp。
- 时间地点前加入系统时钟 Symbol；2×4 右侧备注改为右对齐。
- 4×4 大号文案在最大规格下出现末字裁切，将主字号调整为 23fp、单位字号调整为 16fp，复测三档尺寸均完整。

## 交互与无障碍检查

- `completeTask`、`startFocus`、`stopFocus`、`restoreAutoScene`、`switchScene` 使用 message FormLink。
- 其余入口使用 router FormLink 打开服务页。
- 主按钮、完成与切换入口均保留可读文本，不仅依赖颜色或图标表达含义。
- `fontScaleFollowSystem` 已开启；默认字体缩放下 Previewer 无裁切，超大字体仍建议真机复核。

## 最终结果

通过。2×2、2×4、4×4 的最小、默认、最大 Previewer 规格均完成视觉对比，无 P0/P1/P2 遗留问题。
