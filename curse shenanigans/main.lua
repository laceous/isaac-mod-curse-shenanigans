local mod = RegisterMod('Curse Shenanigans', 1)
local game = Game()

if REPENTOGON then
  mod.curses = nil
  
  function mod:onGameExit()
    mod.curses = nil
  end
  
  function mod:onCurseEval(curses)
    if mod.curses then
      curses = mod.curses
      mod.curses = nil
      return curses
    end
  end
  
  function mod:onRender()
    mod:RemoveCallback(ModCallbacks.MC_MAIN_MENU_RENDER, mod.onRender)
    mod:RemoveCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)
    mod:setupImGui()
  end
  
  function mod:localize(category, key)
    local s = Isaac.GetString(category, key)
    return (s == nil or s == 'StringTable::InvalidCategory' or s == 'StringTable::InvalidKey') and key or s
  end
  
  function mod:getXmlModName(sourceid)
    local entry = XMLData.GetModById(sourceid)
    if entry and type(entry) == 'table' and entry.name and entry.name ~= '' then
      return entry.name
    end
    
    return nil
  end
  
  function mod:getModdedCurses()
    local curses = {}
    
    local id = LevelCurse.NUM_CURSES - 1
    local entry = XMLData.GetEntryById(XMLNode.CURSE, 1 << id)
    while entry and type(entry) == 'table' do
      table.insert(curses, entry)
      
      id = id + 1
      entry = XMLData.GetEntryById(XMLNode.CURSE, 1 << id)
    end
    
    return curses
  end
  
  function mod:getStageApiBaseStage(name)
    local level = game:GetLevel()
    local stage = level:GetStage()
    local stageType = level:GetStageType()
    
    for n, v in pairs(StageAPI.CustomStages) do
      if n ~= name and
         v.XLStage and v.XLStage.Name and v.XLStage.Name == name and
         v.Replaces and v.Replaces.OverrideStage == stage and v.Replaces.OverrideStageType == stageType
      then
        return v
      end
    end
    
    return nil
  end
  
  function mod:reloadStage()
    if StageAPI and StageAPI.Loaded and StageAPI.CurrentStage and StageAPI.CurrentStage.Name and not StageAPI.CurrentStage.NormalStage then
      -- if xl stage
      local currentStage = mod:getStageApiBaseStage(StageAPI.CurrentStage.Name) or StageAPI.CurrentStage
      StageAPI.GotoCustomStage(currentStage, false, true)
    else
      local level = game:GetLevel()
      local stage = level:GetStage()
      local stageType = level:GetStageType()
      local stageTypeMap = {
                             [StageType.STAGETYPE_WOTL]         = 'a',
                             [StageType.STAGETYPE_AFTERBIRTH]   = 'b',
                             [StageType.STAGETYPE_REPENTANCE]   = 'c',
                             [StageType.STAGETYPE_REPENTANCE_B] = 'd'
                           }
      
      local letter = stageTypeMap[stageType]
      if letter then
        stage = stage .. letter
      end
      
      Isaac.ExecuteCommand('stage ' .. stage)
    end
  end
  
  function mod:removeCurse(curse)
    local level = game:GetLevel()
    
    level:RemoveCurses(curse)
    local curses = level:GetCurses()
    
    -- switch permanent debug options over to normal api options
    if curses & curse == curse then
      Isaac.ExecuteCommand('curse 0')
      level:AddCurse(curses & ~curse, false)
    end
  end
  
  function mod:setupImGui()
    if not ImGui.ElementExists('shenanigansMenu') then
      ImGui.CreateMenu('shenanigansMenu', '\u{f6d1} Shenanigans')
    end
    ImGui.AddElement('shenanigansMenu', 'shenanigansMenuItemCurses', ImGuiElement.MenuItem, '\u{f54c} Curse Shenanigans')
    ImGui.CreateWindow('shenanigansWindowCurses', 'Curse Shenanigans')
    ImGui.LinkWindowToElement('shenanigansWindowCurses', 'shenanigansMenuItemCurses')
    
    ImGui.AddTabBar('shenanigansWindowCurses', 'shenanigansTabBarCurses')
    ImGui.AddTab('shenanigansTabBarCurses', 'shenanigansTabCurses', 'Curses')
    ImGui.AddTab('shenanigansTabBarCurses', 'shenanigansTabCursesModded', 'Curses (Modded)')
    
    local idx = 0
    for i, v in ipairs({
                        { id = LevelCurse.CURSE_OF_DARKNESS   , name = '#CURSE_OF_DARKNESS_NAME' },
                        { id = LevelCurse.CURSE_OF_LABYRINTH  , name = '#CURSE_OF_THE_LABYRINTH_NAME', hint = 'Toggling will reload stage, Crashes in The Void' },
                        { id = LevelCurse.CURSE_OF_THE_LOST   , name = '#CURSE_OF_THE_LOST_NAME' },
                        { id = LevelCurse.CURSE_OF_THE_UNKNOWN, name = '#CURSE_OF_THE_UNKNOWN_NAME' },
                        { id = LevelCurse.CURSE_OF_THE_CURSED , name = '#CURSE_OF_THE_CURSED_NAME'   , hint = 'Move to new room after toggling' },
                        { id = LevelCurse.CURSE_OF_MAZE       , name = '#CURSE_OF_THE_MAZE_NAME' },
                        { id = LevelCurse.CURSE_OF_BLIND      , name = '#CURSE_OF_THE_BLIND_NAME'    , hint = 'Move to new room after toggling' },
                        { id = LevelCurse.CURSE_OF_GIANT      , name = '#CURSE_OF_THE_GIANT_NAME'    , hint = 'May crash game! Toggling will reload stage' },
                      })
    do
      idx = i
      local keys = {}
      table.insert(keys, mod:localize('Curses', v.name))
      if v.hint then
        table.insert(keys, v.hint)
      end
      mod:processCurse('shenanigansTabCurses', 'shenanigansChkCurse', i, v.id, keys)
    end
    
    for _, v in ipairs(mod:getModdedCurses()) do
      idx = idx + 1
      local keys = {}
      table.insert(keys, v.name or '')
      if v.sourceid and v.sourceid ~= '' then
        local modName = mod:getXmlModName(v.sourceid)
        table.insert(keys, modName or v.sourceid)
      end
      table.insert(keys, 'May require moving to new room')
      table.insert(keys, 'Might not support toggling')
      if v.id and v.id ~= '' then
        local id = tonumber(v.id)
        if math.type(id) == 'integer' then
          mod:processCurse('shenanigansTabCursesModded', 'shenanigansChkCurseModded', idx, id, keys)
        end
      end
    end
  end
  
  function mod:processCurse(tab, chkIdPrefix, idx, curse, keys)
    local chkId = chkIdPrefix .. idx
    ImGui.AddCheckbox(tab, chkId, idx .. '.' .. table.remove(keys, 1), nil, false)
    if #keys > 0 then
      ImGui.SetHelpmarker(chkId, table.concat(keys, ', '))
    end
    ImGui.AddCallback(chkId, ImGuiCallback.Render, function()
      local level = game:GetLevel()
      ImGui.UpdateData(chkId, ImGuiData.Value, level:GetCurses() & curse == curse)
    end)
    ImGui.AddCallback(chkId, ImGuiCallback.Edited, function(b)
      if Isaac.IsInGame() then
        local level = game:GetLevel()
        if b then
          if curse == LevelCurse.CURSE_OF_LABYRINTH or curse == LevelCurse.CURSE_OF_GIANT then
            mod.curses = level:GetCurses() | curse
            mod:reloadStage()
          else
            level:AddCurse(curse, false)
          end
        else
          if curse == LevelCurse.CURSE_OF_LABYRINTH or curse == LevelCurse.CURSE_OF_GIANT then
            mod:removeCurse(curse)
            mod.curses = level:GetCurses() & ~curse
            mod:reloadStage()
          else
            mod:removeCurse(curse)
          end
        end
      end
    end)
  end
  
  mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
  mod:AddPriorityCallback(ModCallbacks.MC_POST_CURSE_EVAL, CallbackPriority.IMPORTANT, mod.onCurseEval)
  mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER, mod.onRender)
  mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)
end