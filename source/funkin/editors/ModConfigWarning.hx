package funkin.editors;

import funkin.backend.assets.ModsFolderLibrary;
import flixel.FlxState;

class ModConfigWarning extends UIState {
	public static var hadPopup:Bool = false;

	var library:ModsFolderLibrary = null;
	var goToState:Class<FlxState>;

	public static inline var defaultModConfigText = 
'[Common]
MOD_NAME="YOUR MOD NAME HERE"
MOD_DESCRIPTION="YOUR MOD DESCRIPTION HERE"
MOD_AUTHOR="YOU/YOUR TEAM HERE"
MOD_VERSION="YOUR MOD\'S VERSION HERE"

# DO NOT EDIT!! this is used to check for version compatibility!
MOD_API_VERSION=1

MOD_DOWNLOAD_LINK="YOUR MOD PAGE LINK HERE"

# Not supported yet
;MOD_ICON64="path/to/icon64.png"
;MOD_ICON32="path/to/icon32.png"
;MOD_ICON16="path/to/icon16.png"
MOD_ICON="path/to/icon.png"

[Flags]
DISABLE_WARNING_SCREEN=true
# Set this to false if you want to bring back the warning state (prior to 1.0.0)
# NOTE: Beta warning state has been renamed from BetaWarningState.hx to WarningState.hx

[Discord]
MOD_DISCORD_CLIENT_ID=""
MOD_DISCORD_LOGO_KEY=""
MOD_DISCORD_LOGO_TEXT=""';

	public function new(library:ModsFolderLibrary, ?goToState:Class<FlxState>) {
		super();
		this.library = library;
		this.goToState = goToState != null ? goToState : funkin.menus.TitleState;
	}

	override function createPost() {
		super.createPost();
		hadPopup = true;

		var substate = new UIWarningSubstate("Missing mod folder configuration!", "Your mod is currently missing a mod config file!\n\nWould you like to automatically generate one?\n\n(PS: If this is not your mod please disable Developer mode to stop this popup from appearing.)", [
			{
				label: "Not Now",
				color: 0x969533,
				onClick: function (_) {
					MusicBeatState.skipTransOut = MusicBeatState.skipTransIn = false;
					FlxG.switchState(cast Type.createInstance(goToState, []));
				}
			},
			{
				label: "Yes",
				onClick: function(_) {
					var path = '${library.folderPath}/data/config/modpack.ini';
					CoolUtil.safeSaveFile(path, defaultModConfigText);
					openSubState(new UIWarningSubstate("Created mod config!", "Your mod config file has been created at " + path + "!", [
						{
							label: "Ok",
							onClick: function (_) {
								MusicBeatState.skipTransOut = MusicBeatState.skipTransIn = false;
								FlxG.switchState(cast Type.createInstance(goToState, []));
							}
						},
					], false));
				}
			}
		], false);
		openSubState(substate);
	}
}