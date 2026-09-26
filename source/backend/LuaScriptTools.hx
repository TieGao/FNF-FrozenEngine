package backend;

#if (LUA_ALLOWED && sys)
import luahscript.LuaTools;
import luahscript.exprs.LuaConst;
import luahscript.exprs.LuaExpr;

/**
 * luahscript 的 LuaExpr AST 遍历辅助，供 LuaScriptPreload 抽取脚本里的资源名。
 * 与 NF 的 ScriptExprTools 同源，但只保留 lua 这一半 —— hscript 那半（hx_*）不属于本次移植。
 */
class LuaScriptTools
{
	/**
	 * 取字面量值。
	 * 只认 EParent 包裹的字符串 / 整数 / 浮点数；变量、`..` 拼接、table 取值一律返回 null
	 * —— 这是静态分析的固有能力边界，不是 bug。
	 */
	public static function getValue(e:LuaExpr):Dynamic
	{
		if (e == null) return null;
		return switch (e.expr)
		{
			case EParent(inner): getValue(inner);
			case EConst(c):
				switch (c)
				{
					case CString(s, _): s;
					case CInt(i): i;
					case CFloat(f): f;
					case CTripleDot: null;
				}
			case _: null;
		}
	}

	/**
	 * 递归遍历整棵 AST；每遇到一次函数调用，就把 (被调表达式, 实参数组) 交给 func。
	 * 被调表达式会先用 LuaTools.recursion 剥掉外层 EParent，
	 * 所以回调里可以直接写 `case EIdent('precacheImage'):`。
	 */
	public static function searchCallback(e:LuaExpr, ?func:LuaExpr->Array<LuaExpr>->Void):Void
	{
		if (e == null) return;
		switch (e.expr)
		{
			case EConst(_), EIdent(_), EGoto(_), ELabel(_):
			case EBreak, EContinue, EIgnore:
			case EParent(inner):
				searchCallback(inner, func);
			case EField(inner, _):
				searchCallback(inner, func);
			case ELocal(inner):
				searchCallback(inner, func);
			case EBinop(_, e1, e2):
				searchCallback(e1, func);
				searchCallback(e2, func);
			case EPrefix(_, inner):
				searchCallback(inner, func);
			case ECall(callee, params):
				if (func != null)
				{
					LuaTools.recursion(callee, function(c:LuaExpr) {
						func(c, params);
					});
				}
				searchCallback(callee, func);
				for (p in params) searchCallback(p, func);
			case ETd(ae):
				for (x in ae) searchCallback(x, func);
			case EAnd(ae):
				for (x in ae) searchCallback(x, func);
			case EIf(cond, body, eis, eel):
				searchCallback(cond, func);
				searchCallback(body, func);
				if (eis != null) for (branch in eis)
				{
					searchCallback(branch.cond, func);
					searchCallback(branch.body, func);
				}
				if (eel != null) searchCallback(eel, func);
			case ERepeat(body, cond):
				searchCallback(body, func);
				searchCallback(cond, func);
			case EWhile(cond, inner):
				searchCallback(cond, func);
				searchCallback(inner, func);
			case EForNum(_, body, start, end, step):
				searchCallback(body, func);
				searchCallback(start, func);
				searchCallback(end, func);
				if (step != null) searchCallback(step, func);
			case EForGen(body, iterator, _, _):
				searchCallback(iterator, func);
				searchCallback(body, func);
			case EFunction(_, inner):
				searchCallback(inner, func);
			case EReturn(inner):
				searchCallback(inner, func);
			case EArray(inner, index):
				searchCallback(inner, func);
				searchCallback(index, func);
			case ETable(fields):
				for (field in fields)
				{
					if (field.key != null) searchCallback(field.key, func);
					searchCallback(field.v, func);
				}
		}
	}
}
#end
