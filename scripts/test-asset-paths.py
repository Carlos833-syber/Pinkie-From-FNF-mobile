#!/usr/bin/env python3
"""Test the real asset/song resolver and Lua stack guard without a native window.

The OpenFL test double models typed packaged asset IDs, so filesystem copies
cannot conceal a missing library prefix. Requires Haxe 4.2.5 and the
pinned hxvm-luajit Haxelib installed by scripts/setup-android.sh.
"""

from pathlib import Path
import subprocess
import tempfile

# Use the pinned superclass itself; only the native Lua API is doubled.
library_output = subprocess.check_output(["haxelib", "path", "hxvm-luajit"], text=True)
LUA_LIBRARY = next(line for line in library_output.splitlines() if Path(line).is_dir())

ROOT = Path(__file__).resolve().parents[1]
STUBS = {
    "TitleState.hx": '''class TitleState { public static var curDir = "assets"; }''',
    "flixel/system/FlxAssets.hx": '''package flixel.system;
        typedef FlxSoundAsset = Dynamic;
        typedef FlxGraphicAsset = Dynamic;''',
    "flixel/FlxG.hx": '''package flixel;
        class FlxG {
            public static var random = {int: function(min:Int, max:Int) return min};
            public static var bitmap = new TestBitmapCache();
        }
        class TestBitmapCache {
            public function new() {}
            public function get(key:String):flixel.graphics.FlxGraphic return null;
            public function remove(graphic:flixel.graphics.FlxGraphic) graphic.destroy();
        }''',
    "flixel/graphics/FlxGraphic.hx": '''package flixel.graphics;
        class FlxGraphic {
            public var persist = true;
            public var useCount = 0;
            public var key = "test";
            public var assetsKey:String;
            public var bitmap:openfl.display.BitmapData = new openfl.display.BitmapData();
            public function new() {}
            public function destroy() { bitmap = null; }
            public static function fromBitmapData(b:Dynamic, u:Bool, k:String, c:Bool = true):FlxGraphic
                return new FlxGraphic();
        }''',
    "flixel/graphics/frames/FlxAtlasFrames.hx": '''package flixel.graphics.frames;
        class FlxAtlasFrames {
            public var description:String;
            public function new(description:String) this.description = description;
            public static function fromSparrow(source:Dynamic, description:String):FlxAtlasFrames {
                if (!openfl.utils.Assets.exists(source, IMAGE)) throw "Missing image: " + source;
                return new FlxAtlasFrames(description);
            }
            public static function fromTexturePackerJson(source:Dynamic, description:String):FlxAtlasFrames
                return new FlxAtlasFrames(openfl.utils.Assets.getText(description));
            public static function fromSpriteSheetPacker(source:Dynamic, description:String):FlxAtlasFrames
                return new FlxAtlasFrames(openfl.utils.Assets.getText(description));
        }''',
    "openfl/display/BitmapData.hx": '''package openfl.display;
        class BitmapData {
            public function new() {}
            public static function fromFile(path:String):BitmapData return null;
        }''',
    "openfl/media/Sound.hx": '''package openfl.media;
        class Sound { public static function fromFile(path:String):Sound return null; }''',
    "openfl/utils/AssetType.hx": '''package openfl.utils;
        enum abstract AssetType(String) from String to String {
            var TEXT = "TEXT"; var IMAGE = "IMAGE"; var SOUND = "SOUND"; var MUSIC = "MUSIC";
        }''',
    "openfl/utils/Assets.hx": '''package openfl.utils;
        class Assets {
            public static var types:Map<String, AssetType> = [];
            public static var texts:Map<String, String> = [];
            public static var cache = new TestAssetCache();
            public static function exists(path:String, ?type:AssetType):Bool
                return types.exists(path) && (type == null || types[path] == type);
            public static function getText(path:String):String {
                if (!exists(path, TEXT)) throw "Missing text: " + path;
                return texts.exists(path) ? texts[path] : path;
            }
            public static function getBitmapData(path:String):openfl.display.BitmapData return null;
            public static function getSound(path:String):openfl.media.Sound return null;
        }
        class TestAssetCache {
            public var removed:Array<String> = [];
            public function new() {}
            public function removeBitmapData(key:String) removed.push(key);
        }''',
    "lime/utils/Assets.hx": '''package lime.utils; typedef Assets = openfl.utils.Assets;''',
    "llua/State.hx": '''package llua;
        class State {
            public var stack:Array<Dynamic> = [];
            public var globals:Map<String, Dynamic> = [];
            public function new() {}
        }''',
    "llua/Convert.hx": '''package llua;
        class Convert {
            public static function toLua(state:State, value:Dynamic):Void state.stack.push(value);
            public static function fromLua(state:State, index:Int):Dynamic
                return state.stack[index < 0 ? state.stack.length + index : index - 1];
        }''',
    "llua/LuaL.hx": '''package llua;
        class LuaL {
            public static function newstate():State return new State();
            public static function openlibs(state:State):Void {}
            public static function dostring(state:State, script:String):Int return 0;
            public static function dofile(state:State, script:String):Int return 0;
        }''',
    "Lua_helper.hx": '''class Lua_helper {
        public static function add_callback(state:llua.State, name:String, callback:Dynamic):Void
            state.globals[name] = callback;
    }''',
    "llua/Lua.hx": '''package llua;
        class Lua {
            public static function version():String return "test";
            public static function init_callbacks(state:State):Void {}
            public static function gettop(state:State):Int return state.stack.length;
            public static function settop(state:State, top:Int):Void {
                while (state.stack.length < top) state.stack.push(null);
                state.stack.resize(top);
            }
            public static function getglobal(state:State, name:String):Void
                state.stack.push(state.globals[name]);
            public static function setglobal(state:State, name:String):Void
                state.globals[name] = state.stack.pop();
            public static function pushnil(state:State):Void state.stack.push(null);
            public static function isfunction(state:State, index:Int):Bool
                return Reflect.isFunction(Convert.fromLua(state, index));
            public static function pcall(state:State, count:Int, results:Int, error:Int):Int {
                var args = state.stack.splice(state.stack.length - count, count);
                var callback = state.stack.pop();
                try {
                    state.stack.push(Reflect.callMethod(null, callback, args));
                    return 0;
                } catch (failure:Dynamic) {
                    state.stack.push(Std.string(failure));
                    return 1;
                }
            }
            public static function tostring(state:State, index:Int):String
                return Std.string(Convert.fromLua(state, index));
            public static function pop(state:State, count:Int):Void
                state.stack.resize(state.stack.length - count);
            public static function close(state:State):Void state.stack = [];
        }''',
    "TestAssets.hx": '''import openfl.utils.Assets;
        import openfl.utils.AssetType;
        import flixel.graphics.FlxGraphic;
        class TestAssets {
            static function equal(actual:Dynamic, expected:Dynamic) {
                if (actual != expected) throw 'Expected $expected, got $actual';
            }
            static function main() {
                var prefix = "shared:assets/shared/images/";
                for (name in ["characters/GF_assets", "fixture"]) {
                    Assets.types[prefix + name + ".png"] = IMAGE;
                    for (ext in ["xml", "json", "txt"])
                        Assets.types[prefix + name + "." + ext] = TEXT;
                }
                Paths.setCurrentLevel("week0");
                equal(Paths.getSparrowAtlas("characters/GF_assets", "shared").description,
                    prefix + "characters/GF_assets.xml");
                equal(Paths.getSparrowAtlas("characters/GF_assets").description,
                    prefix + "characters/GF_assets.xml");
                equal(Paths.getPackerAtlasJson("fixture", "shared").description, prefix + "fixture.json");
                equal(Paths.getPackerAtlas("fixture", "shared").description, prefix + "fixture.txt");
                equal(Paths.exists("assets/shared/images/characters/GF_assets.xml"), true);
                Assets.types["assets/images/preload.png"] = IMAGE;
                Assets.types["assets/images/preload.xml"] = TEXT;
                equal(Paths.getSparrowAtlas("preload").description, "assets/images/preload.xml");

                var chart = "assets/data/tutorial/tutorial.json";
                Assets.types[chart] = TEXT;
                Assets.texts[chart] = '{"song":{"song":"Tutorial","notes":[],"bpm":100,"needsVoices":false,"speed":1,"player1":"bf","player2":"gf"}}';
                equal(Song.loadFromJson("tutorial").song, "Tutorial");
                equal(Song.loadFromJson("missing", "missing"), null);
                Assets.texts[chart] = "invalid chart";
                var invalidRejected = false;
                try Song.loadFromJson("tutorial") catch (_:Dynamic) invalidRejected = true;
                equal(invalidRejected, true);

                var unused = new FlxGraphic();
                Paths.trackGraphicAsset(unused, "assets/shared/images/unused.png");
                var active = new FlxGraphic(); active.useCount = 1;
                var cache:Map<String, FlxGraphic> = ["unused" => unused, "active" => active];
                Paths.releaseUnusedGraphics(cache);
                equal(cache.exists("unused"), false);
                equal(unused.bitmap, null);
                equal(cache.exists("active"), true);
                equal(active.bitmap != null, true);
                equal(Assets.cache.removed[0], prefix + "unused.png");
                var lua = new ModchartLuaVM();
                lua.setGlobalVar("update", function() return 32);
                lua.setGlobalVar("withArgs", function(a:Int, b:Int) return a + b);
                lua.setGlobalVar("throw", function() { throw "callback error"; });
                // The pinned base implementation demonstrably leaks a missing callback.
                var base = new vm.lua.LuaVM();
                base.call("missing", []);
                equal(llua.Lua.gettop(base.state), 1);
                llua.Lua.pushnil(lua.state);
                var top = llua.Lua.gettop(lua.state);
                for (_ in 0...1000) {
                    equal(lua.call("update", []), 32);
                    equal(lua.call("missing", []), null);
                }
                equal(lua.call("withArgs", [2, 4]), 6);
                equal(llua.Lua.gettop(lua.state), top);
                var error = "";
                lua.errorHandler = function(message:String) error = message;
                lua.call("throw", []);
                equal(error, "callback error");
                equal(llua.Lua.gettop(lua.state), top);
                Sys.println("Packaged atlas paths, charts, graphics ownership and Lua stack guard passed.");
            }
        }''',
}

with tempfile.TemporaryDirectory(prefix="pinkie-asset-tests-") as temp:
    directory = Path(temp)
    for relative, content in STUBS.items():
        path = directory / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    subprocess.run(
        ["haxe", "-cp", str(ROOT / "source"), "-cp", LUA_LIBRARY, "-cp", temp, "--run", "TestAssets"],
        cwd=temp,
        check=True,
    )
