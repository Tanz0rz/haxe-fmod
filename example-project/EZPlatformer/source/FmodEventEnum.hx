// Generated haxefmod constants - do not edit (regenerate from FMOD Studio or via haxelib run haxefmod generate)

enum FmodEventEnum {
	DialogueSpeak;
	MusicMainLevel;
	SFXCoin;
	SFXJump;
	SFXSpatial;
}

// Static extension: `using FmodEventEnum.FmodEventTools;` enables
// FmodEventEnum.MusicMainLevel.path() and .guid()
class FmodEventTools {
	public static inline function path(event:FmodEventEnum):String {
		return switch (event) {
			case DialogueSpeak: "event:/Dialogue/Speak";
			case MusicMainLevel: "event:/Music/MainLevel";
			case SFXCoin: "event:/SFX/Coin";
			case SFXJump: "event:/SFX/Jump";
			case SFXSpatial: "event:/SFX/Spatial";
		};
	}

	public static inline function guid(event:FmodEventEnum):String {
		return switch (event) {
			case DialogueSpeak: "{d166c4dc-4c88-4f5d-a1e6-95aaf0d29747}";
			case MusicMainLevel: "{e5187c3f-0517-463e-b458-de9ef1a9f750}";
			case SFXCoin: "{6c656399-97f5-432f-9817-c10c8c56939d}";
			case SFXJump: "{4562f533-1e6b-4ce9-a40a-814283edde66}";
			case SFXSpatial: "{82396b6b-8474-4dd9-8fd7-5f623ec827fa}";
		};
	}
}
