# NMV 脚本 API 移植计划 — 60 常见坑速查

| 坑 | 后果 | 规避 |
|---|---|---|
| `InterpEx.hx` 抄成 Impostor 版 | 行为分叉：Impostor 有私有 `enum Stop`、重写 `whileLoop`/`doWhileLoop`/`exprReturn`；NMV 用 `Type.enumConstructor` 反射、只重写 `forLoop`、多 `cachedFields` | 抄 NMV 那份（更成熟） |
| `fromFile` 签名抄错 | NMV：`fromFile(file, name, autoExecute=true, ?shareables, ?modFolder)`；Impostor 第三参是 `additionalVars:Map` | 以 NMV 为准；抄错**不报错、脚本静默不执行** |
| 官方 hscript-iris 1.1.3 不换 fork | `EFor`/`CString` 两个语法节点解析失败，整个脚本层不可用 | Phase 0 换 git fork，不可跳过 |
| `WeekData`/`StageData` 直接映射 | 同名异义，读出来空/错值，不报错 | 先 throw 或写转换函数 |
| `newShader(name)` 路径按 NMV 找 | 找不到静默回退，shader 全丢 | 接 FE 的 `Paths` shader 约定 |
| 上下文变量引用时机太早 | 拿到 null | 脚本执行挂 PlayState create 末尾 |
| 补桩映射错 | 不报错、只表现成"没用" | 全部主动 throw 保底 |
| GLSL 源码字符串写注释 | 非 ASCII 静默丢物体（本项目既有教训） | GLSL 内只用英文/ASCII 注释 |
| 宏关闭后残留 | FE 宏两向验证铁律被破 | 每阶段开关各编译一次 |
| 脚本层目录撞名 | 后续接 CNE/NF 方言混淆 | 用 `source/nmv/` 隔离 |

## 文档约定

- 本目录为**未提交**工作文档，只服务本分支开发过程；结论稳定后再决定是否并入正式文档。
- 每完成一个 Phase，回填到对应小节的"完成判据"。
