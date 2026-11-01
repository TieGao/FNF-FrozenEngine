package nmv.modchart;

/** NMV `SubModifier`：同名子模（`xmod0..xmod3` 这类），排序固定 LAST、不参与 update。 */
class SubModifier extends Modifier
{
	var name:String = 'unspecified';

	override function getName():String
		return name;

	override function getOrder():Int
		return Modifier.ModifierOrder.LAST;

	override function doesUpdate():Bool
		return false;

	public function new(name:String, modMgr:ModManager, ?parent:Modifier)
	{
		super(modMgr, parent);
		this.name = name;
	}
}
