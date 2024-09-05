namespace BlockToBlock {

    Utils@ utils;
    Conversion@ conv;

    int totalBlocks = 0;
    int totalBlocksConverted = 0;

    void Init() {
        log("Initializing BlockToBlock.", LogLevel::Info, 3, "BlockToItem::Init");

        utils = Utils();
        conv = Conversion();

        ConversionPreparation();
    }

    void ConversionPreparation() {
        log("Converting block to block.", LogLevel::Info, 3, "ConvertBlockToItem");
        
        CGameCtnApp app = GetApp();
        CGameCtnEditorCommon editor = cast<CGameCtnEditorCommon@>(app.Editor);
        CGameEditorPluginMapMapType pmt = editor.PluginMapType;
        CGameEditorGenericInventory inventory = pmt.Inventory;

        CGameCtnArticleNodeDirectory blocksNode = cast<CGameCtnArticleNodeDirectory@>(inventory.RootNodes[0]);
        totalBlocks = utils.CountBlocks(blocksNode);
        ExploreNode(blocksNode);
    }

    void ExploreNode(CGameCtnArticleNodeDirectory@ parentNode, string folder = "") {
        for (uint i = 0; i < parentNode.ChildNodes.Length; i++) {
            CGameCtnArticleNode node = parentNode.ChildNodes[i];
            if (node.IsDirectory) {
                ExploreNode(cast<CGameCtnArticleNodeDirectory@>(node), folder + node.Name + "/");
            } else {
                auto ana = cast<CGameCtnArticleNodeArticle@>(node);
                if (ana.Article is null || ana.Article.IdName.ToLower().EndsWith("customblock")) {
                    log("Skipping block " + ana.Name + " because it's a custom block.", LogLevel::Info, 3, "ExploreNode");
                    continue;
                }
                string blockSaveLocation = "VanillaBlockToCustomBlock/" + folder + ana.Name + ".Block.Gbx";
                totalBlocksConverted++;
                log("Converting block " + ana.Name + " to block.", LogLevel::Info, 3, "ExploreNode");
                string fullBlockSaveLocation = IO::FromUserGameFolder("Blocks/" + blockSaveLocation); // Changed to "Block/" for blocks

                if (IO::FileExists(fullBlockSaveLocation)) {
                    log("Block " + blockSaveLocation + " already exists. Skipping.", LogLevel::Info, 3, "ExploreNode");
                } else {
                    auto block = cast<CGameCtnBlockInfo@>(ana.Article.LoadedNod);

                    if (block is null) {
                        log("Block " + ana.Name + " is null. Skipping.", LogLevel::Info, 3, "ExploreNode");
                        continue;
                    }

                    if (string(block.Name).ToLower().Contains("water")) {
                        log("Water cannot be converted to a custom block/item. Skipping.", LogLevel::Info, 3, "ExploreNode");
                        continue;
                    }

                    if (utils.IsBlacklisted(block.Name)) {
                        log("Block " + block.Name + " is blacklisted. Skipping.", LogLevel::Info, 3, "ExploreNode");
                        continue;
                    }

                    log("Converting block " + block.Name + " to item.", LogLevel::Info, 3, "ExploreNode");
                    log("Saving block to " + blockSaveLocation, LogLevel::Info, 3, "ExploreNode");
                    
                    conv.ConvertBlockToBlock(block, blockSaveLocation);
                }
            }
        }
    }

    class Conversion {
        int2 button_Icon = int2(0, 0);
        int2 button_DirectionIcon = int2(0, 0);

        void ConvertBlockToBlock(CGameCtnBlockInfo@ blockInfo, string blockSaveLocation) {
            log("Converting block to block.", LogLevel::Info, 3, "ConvertBlockToBlock");

            CGameCtnApp app = GetApp();
            CGameCtnEditorCommon editor = cast<CGameCtnEditorCommon@>(app.Editor);
            CGameEditorPluginMapMapType pmt = editor.PluginMapType;

            pmt.RemoveAll();

            yield();

            pmt.PlaceMode = CGameEditorPluginMapMapType::EPlaceMode::GhostBlock;

            yield();

            @pmt.CursorBlockModel = blockInfo;

            yield();

            int nBlocks = pmt.Blocks.Length;
            log("Starting to place the block: " + blockInfo.Name, LogLevel::Info, 3, "ConvertBlockToBlock");
            while (pmt.Blocks.Length == nBlocks) {
                mouse.Click();
                yield();
            }
            editor.ButtonBlockItemCreateModeOnClick();

            yield();
            
            // Assuming CGameEditorItem works for blocks aswell...
            // Though this will have to be tested. If not CGameEditorMethod seems most likely to contain what we need.
            
            while (cast<CGameEditorItem>(app.Editor) is null) {
                @editor = cast<CGameCtnEditorCommon@>(app.Editor);
                if (editor !is null && editor.PickedBlock !is null && editor.PickedBlock.BlockInfo.Name == blockInfo.Name) {
                    log("Clicking to confirm the selection.", LogLevel::Info, 3, "ConvertBlockToBlock");
                    mouse.Click();
                }
                yield();
            }
            
            CGameEditorItem editorItem = cast<CGameEditorItem>(app.Editor);
            editorItem.IdName = blockInfo.Name;
 
            editorItem.PlacementParamGridHorizontalSize = 32;
            editorItem.PlacementParamGridVerticalSize = 8;
            editorItem.PlacementParamFlyStep = 8;

            log("Clicking the button to set the icon.", LogLevel::Info, 3, "ConvertBlockToItem");
            mouse.Click(button_Icon);

            yield();

            log("Clicking the button to set the direction icon.", LogLevel::Info, 3, "ConvertBlockToItem");
            mouse.Click(button_DirectionIcon);

            yield();

            log("Saving block to " + blockSaveLocation, LogLevel::Info, 3, "ConvertBlockToItem");
            editorItem.FileSaveAs(blockSaveLocation);

            yield();

            app.BasicDialogs.String = blockSaveLocation;

            yield();

            app.BasicDialogs.DialogSaveAs_OnValidate();

            yield();

            app.BasicDialogs.DialogSaveAs_OnValidate();
            
            yield();

            cast<CGameEditorItem>(app.Editor).Exit();

            while (cast<CGameEditorItem>(app.Editor) !is null) {
                yield();
            }

            yield();

            @editor = cast<CGameCtnEditorCommon@>(app.Editor);
            @pmt = editor.PluginMapType;
            pmt.Undo();

            // pmt.RemoveAll();
        }
    }

    class Utils {
        bool IsBlacklisted(string blockName) {
            for (uint i = 0; i < blockToBlockBlacklist.Length; i++) {
                if (blockName.ToLower().Contains(blockToBlockBlacklist[i])) {
                    return true;
                }
            }
        }

        int CountBlocks(CGameCtnArticleNodeDirectory@ parentNode) {
            int count = 0;
            for (uint i = 0; i < parentNode.ChildNodes.Length; i++) {
                CGameCtnArticleNode node = parentNode.ChildNodes[i];
                if (node.IsDirectory) {
                    count += CountBlocks(cast<CGameCtnArticleNodeDirectory@>(node));
                } else {
                    count++;
                }
            }
            return count;
        }

        int BlocksLeftToConvert() {
            return totalBlocks - totalBlocksConverted;
        }
    }




    // ConvertBlockToBlock
}
