package;

import llua.Lua;
import vm.lua.LuaVM;

/** Keep callback results and missing functions from accumulating on Lua's stack. */
class ModchartLuaVM extends LuaVM
{
	override public function call(name:String, args:Array<Any>, ?type:String):Any
	{
		var stackTop = Lua.gettop(state);
		try
		{
			var result = super.call(name, args, type);
			Lua.settop(state, stackTop);
			return result;
		}
		catch (error:Dynamic)
		{
			Lua.settop(state, stackTop);
			throw error;
		}
	}
}
