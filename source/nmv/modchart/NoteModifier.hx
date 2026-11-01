package nmv.modchart;

import nmv.modchart.Modifier.ModifierType;

/** NMV `NoteModifier`：NOTE_MOD 标记，会被 note / receptor / splash 的更新链调用。 */
class NoteModifier extends Modifier
{
	override function getModType():ModifierType
		return NOTE_MOD;
}
