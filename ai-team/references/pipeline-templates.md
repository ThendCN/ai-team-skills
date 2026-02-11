# AI Team 流水线模板

## 模板 1: UI → 实现（Gemini → Codex）

适用于全栈功能开发。

### Gemini Prompt 模板

```
你是一个 UI/前端设计专家。

项目工作目录: {workdir}
技术栈: {tech_stack}

任务: {task_description}

要求:
1. 设计完整的 UI 交互流程
2. 输出可直接使用的前端代码
3. 遵循项目现有的代码风格（参考 {style_reference_dir}）
4. 包含必要的交互逻辑

输出文件: {output_file_path}
```

### Codex Prompt 模板（基于 Gemini 输出）

```
基于已有的 UI 设计实现后端逻辑。

项目工作目录: {workdir}
技术栈: {tech_stack}

UI 文件（由 Gemini 生成）: {gemini_output_files}
UI 设计要点: {design_summary}

任务: {task_description}

要求:
1. 实现 UI 所需的后端接口/逻辑
2. 如需数据库变更，创建 migration 文件
3. 遵循项目编码规范

测试命令: {test_command}
```

## 模板 2: 审查 → 修复

适用于代码质量改进。

### 审查 Prompt

```
Review the application code focusing on:
1. Security vulnerabilities
2. Business logic correctness
3. Error handling gaps
4. Type safety issues

Output a structured report with severity levels.
```

### 修复 Prompt（基于审查结果）

```
Fix the following issues found during code review:

{review_findings}

For each fix:
1. Describe the change
2. Modify the file
3. Verify with tests

Test command: {test_command}
```

## 模板 3: 多模块并行

适用于多个独立模块同时开发。

### 子任务 Prompt 模板

```
实现 {module_name} 模块。

项目工作目录: {workdir}
技术栈: {tech_stack}

功能要求:
{requirements}

文件结构:
- {file_1}: {description_1}
- {file_2}: {description_2}

注意: 此模块与 {other_modules} 并行开发，
请确保接口定义清晰，避免命名冲突。

测试命令: {test_command}
```
