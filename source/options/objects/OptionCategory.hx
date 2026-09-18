package options.objects;

import options.Option;

class OptionCategory
{
    public var id:String;
    public var displayName:String;
    public var rawDisplayName:String;
    public var icon:String;

    public var description:String = '';
    /** 本级直接拥有的选项（顶层分类通常为空，子分类才放） */
    public var options:Array<Option> = [];

    /** 子分类（导航栏的每一项） */
    public var subCategories:Array<OptionCategory> = [];

    /** 父分类引用（子分类自动赋值） */
    public var parent:OptionCategory = null;

    public function new(id:String, displayName:String, icon:String = 'specIcon')
    {
        this.id = id;
        this.rawDisplayName = displayName;
        this.displayName = displayName;
        this.icon = icon;
    }

    /** 新建一个子分类并返回，方便链式添加 */
    public function section(id:String, displayName:String):OptionCategory
    {
        var sub = new OptionCategory(id, displayName, icon);
        sub.parent = this;
        subCategories.push(sub);
        return sub;
    }

    /** 往本级添加选项 */
    public function add(o:Option):Option
    {
        o.ownerCategory = this;
        options.push(o);
        return o;
    }

    public function refreshLanguage():Void
    {
        displayName = Language.getPhrase('options.category.${id}.title', rawDisplayName);
        description = Language.getPhrase('options.category.${id}.description', description);

        for (sub in subCategories)
            sub.refreshLanguage();

        for (opt in options)
            opt.refreshLanguage();
    }

    /** 递归收集本级 + 所有子分类的选项（搜索/统计用） */
    public function allOptions():Array<Option>
    {
        var out:Array<Option> = [];
        for (o in options) out.push(o);
        for (sub in subCategories) for (o in sub.allOptions()) out.push(o);
        return out;
    }

    /** 是否有子分类（决定导航栏行为） */
    public function hasSubCategories():Bool
    {
        return subCategories.length > 0;
    }
}