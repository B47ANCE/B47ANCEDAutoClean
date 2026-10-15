"""Read-only installed UI contracts. Source fingerprints are not runtime proof."""
import hashlib
import json
from pathlib import Path


def audit(game,record=False):
    paths=['media/lua/client/ISUI/ISProgressBar.lua',
           'media/lua/client/ISUI/ISUIElement.lua',
           'media/lua/client/Foraging/ISSearchManager.lua']
    hashes={p:hashlib.sha256((game/p).read_bytes()).hexdigest() for p in paths}
    progress=(game/paths[0]).read_text(encoding='utf-8-sig')
    element=(game/paths[1]).read_text(encoding='utf-8-sig')
    search=(game/paths[2]).read_text(encoding='utf-8-sig')
    assert 'function ISProgressBar:setProgress(_p)' in progress and 'PZMath.clamp_01(_p)' in progress
    assert 'function ISProgressBar:prerender()' in progress
    for method in ['setWantMouseEvents','setWantKeyEvents','setCapture','setFollowGameWorld',
                   'setRenderThisPlayerOnly','setStencilRect','clearStencilRect']:
        assert 'function ISUIElement:'+method+'(' in element,method
    for marker in ['isoToScreenX(self.player,','isoToScreenY(self.player,','getPlayerScreenLeft(self.player)',
                   'getPlayerScreenTop(self.player)','getCore():getZoom(self.player)','self:setRenderThisPlayerOnly(self.player)']:
        assert marker in search,marker
    result={'gameVersion':'42.21.0','steamBuild':'25485521','runtime':'NOT TESTED',
            'sourceSha256':hashes,'scope':'Client widget rendering, input passthrough and overhead viewport projection only'}
    fixture=Path(__file__).parent/'fixtures/progress_ui_25485521.json'
    if record:fixture.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    assert result==json.loads(fixture.read_text(encoding='utf-8')),'UI source changed; re-audit before use'
    return result
