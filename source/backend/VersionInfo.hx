package backend;

/**
 * 构建时版本信息。
 *
 * lime build 会给每个 haxelib 生成 `-D <库名>=<版本>` 定义（见 export/<平台>/haxe/release.hxml），
 * 而运行时的 Application.current.meta 只有 version / company / name / file / packageName / build
 * 六个键，拿不到库版本 —— 所以只能在编译期用宏读出来。
 *
 * 单独放一个类、且只允许出现基础类型：带 macro 方法的类会被 Haxe 在宏上下文里也编译一遍，
 * 一旦引用了 Flixel 类型（`@:build` / `@:genericBuild` 满地都是）就报
 * "You cannot use @:build inside a macro"。
 */
class VersionInfo
{
    /** 取 `-D <name>=<版本>` 的值；没有该定义时返回 'Unknown'。 */
    public static macro function lib(name:String):haxe.macro.Expr
    {
        var v = haxe.macro.Context.definedValue(name);
        if (v == null || v == '') v = 'Unknown';
        return macro $v{v};
    }
}
