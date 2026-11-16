-- Quest Navigator 1단계: 게임에서 읽을 수 있는 정보 검증용
-- /qn api      : 필요한 API가 존재하는지 확인
-- /qn gear     : 착용 장비 슬롯별 정보와 능력치
-- /qn traits   : 새 특성 시스템(C_Traits)으로 투자 포인트 읽기
-- /qn talents  : 특성 정보
-- /qn item <아이템번호 또는 링크> : 아이템 정보와 능력치 (캐시에 없는 아이템 테스트)
-- /qn quest    : 퀘스트 창이 열린 상태에서 보상 목록 읽기 (선택/고정 구분)
-- /qn auto     : 퀘스트 창이 열릴 때 자동으로 보상 읽기 켜기/끄기
-- /qn log      : 마지막 출력을 SavedVariables에 보관한 내용 개수 표시

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffQN|r " .. tostring(msg))
end

local function S(v)
  if v == nil then return "nil" end
  if issecretvalue and issecretvalue(v) then return "(비밀값)" end
  return tostring(v)
end

local function Safe(label, f, ...)
  local ok, err = pcall(f, ...)
  if not ok then Print("|cffff5555" .. label .. " 오류:|r " .. tostring(err)) end
end

local SLOT_NAMES = {
  [1] = "머리", [2] = "목", [3] = "어깨", [4] = "셔츠", [5] = "가슴", [6] = "허리",
  [7] = "다리", [8] = "발", [9] = "손목", [10] = "손", [11] = "반지1", [12] = "반지2",
  [13] = "장신구1", [14] = "장신구2", [15] = "등", [16] = "주무기", [17] = "보조무기",
  [18] = "원거리", [19] = "휘장",
}

local function GetInfo(link)
  if C_Item and C_Item.GetItemInfo then
    return C_Item.GetItemInfo(link)
  end
  return GetItemInfo(link)
end

local function GetStats(link)
  local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
  if not fn then return nil, "GetItemStats 없음" end
  local t = fn(link)
  if type(t) ~= "table" then return nil, "결과 없음" end
  return t
end

local function StatText(link)
  local t, why = GetStats(link)
  if not t then return "능력치 읽기 실패(" .. S(why) .. ")" end
  local parts = {}
  for k, v in pairs(t) do
    local label = _G[k] or k
    parts[#parts + 1] = S(label) .. " " .. S(v)
  end
  if #parts == 0 then return "능력치 없음/미확인" end
  table.sort(parts)
  return table.concat(parts, ", ")
end

local function ItemLine(link)
  local name, _, quality, ilvl, reqLevel, class, subclass, _, equipLoc = GetInfo(link)
  if not name then
    return "아이템 정보 아직 없음(서버에서 받아오는 중일 수 있음)"
  end
  return S(name) .. " | 등급 " .. S(quality) .. " | 아이템레벨 " .. S(ilvl) .. " | 착용레벨 " .. S(reqLevel)
    .. " | " .. S(class) .. "/" .. S(subclass) .. " | 부위 " .. S(equipLoc)
end

local function IdOf(link)
  return link and tostring(link):match("item:(%d+)") or "?"
end

----------------------------------------------------------------
local function CmdApi()
  local list = {
    "GetInventoryItemLink", "GetItemInfo", "GetItemStats", "GetItemInfoInstant",
    "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo",
    "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemLink", "GetQuestItemInfo",
    "GetQuestLogChoiceInfo", "GetQuestLogRewardInfo", "GetQuestsCompleted",
    "GetItemCount", "UnitClass", "UnitLevel", "GetItemSpell",
  }
  for _, n in ipairs(list) do
    Print(n .. ": " .. (type(_G[n]) == "function" and "있음" or "없음"))
  end
  local tbl = { "C_Item", "C_QuestLog", "C_Map", "C_SpecializationInfo", "C_Traits", "C_ClassTalents", "C_TooltipInfo" }
  for _, n in ipairs(tbl) do
    Print(n .. ": " .. (type(_G[n]) == "table" and "있음" or "없음"))
  end
  if GetBuildInfo then
    local v, b = GetBuildInfo()
    Print("빌드: " .. S(v) .. " (" .. S(b) .. ")")
  end
  Print("전투 중: " .. (InCombatLockdown and InCombatLockdown() and "예" or "아니오"))
end

local function CmdGear()
  if InCombatLockdown and InCombatLockdown() then
    Print("전투 중에는 읽기가 막힐 수 있습니다. 전투 밖에서 다시 실행하세요.")
  end
  local total = {}
  local found = 0
  for slot = 1, 19 do
    local link = GetInventoryItemLink("player", slot)
    if link then
      found = found + 1
      Print("[" .. SLOT_NAMES[slot] .. "] 번호 " .. IdOf(link))
      Print("   " .. ItemLine(link))
      Print("   " .. StatText(link))
    end
  end
  Print("착용 장비 " .. found .. "개 확인")
end

local function CmdTalents()
  if GetNumTalentTabs then
    local tabs = GetNumTalentTabs()
    Print("특성 탭 수: " .. S(tabs))
    for i = 1, (tabs or 0) do
      if GetTalentTabInfo then
        local r = { GetTalentTabInfo(i) }
        local out = {}
        for k = 1, #r do out[#out + 1] = S(r[k]) end
        Print("  탭 " .. i .. ": " .. table.concat(out, " / "))
      end
      if GetNumTalents then
        Print("   특성 개수: " .. S(GetNumTalents(i)))
      end
    end
  else
    Print("GetNumTalentTabs 없음")
  end
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    Print("현재 전문화: " .. S(C_SpecializationInfo.GetSpecialization()))
  end
end

local function CmdItem(arg)
  if not arg or arg == "" then Print("사용법: /qn item 아이템번호  (또는 아이템 링크를 붙여넣기)") return end
  local link = arg:match("|H(item:[^|]+)|h") or ("item:" .. (arg:match("%d+") or ""))
  Print("조회: " .. link)
  Print("   " .. ItemLine(link))
  Print("   " .. StatText(link))
  if GetItemInfoInstant then
    local id, itype, isub, equipLoc = GetItemInfoInstant(link)
    Print("   Instant: 번호 " .. S(id) .. " / " .. S(itype) .. " / " .. S(isub) .. " / " .. S(equipLoc))
  end
end

local function CmdQuest()
  if GetNumQuestChoices then
    local nc = GetNumQuestChoices() or 0
    local nr = GetNumQuestRewards and GetNumQuestRewards() or 0
    local money = GetRewardMoney and GetRewardMoney() or nil
    Print("퀘스트창(완료/보상) 선택 보상 " .. S(nc) .. "개 / 고정 보상 " .. S(nr) .. "개 / 돈 " .. S(money))
    for i = 1, nc do
      local link = GetQuestItemLink and GetQuestItemLink("choice", i)
      Print("  [선택 " .. i .. "] 번호 " .. IdOf(link))
      if link then Print("     " .. ItemLine(link)) Print("     " .. StatText(link)) end
    end
    for i = 1, nr do
      local link = GetQuestItemLink and GetQuestItemLink("reward", i)
      Print("  [고정 " .. i .. "] 번호 " .. IdOf(link))
      if link then Print("     " .. ItemLine(link)) Print("     " .. StatText(link)) end
    end
  end
  -- 퀘스트 로그 선택 시 (퀘스트 수락 전 단계 확인용)
  -- 포에버에서는 GetNumQuestLogChoices 에 퀘스트 번호(questID)를 넘겨야 함
  if GetNumQuestLogChoices then
    local qid = (C_QuestLog and C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest())
      or (GetQuestID and GetQuestID()) or nil
    if qid and qid ~= 0 then
      local ok, n = pcall(GetNumQuestLogChoices, qid, true)
      Print("퀘스트 로그 선택된 퀘스트 " .. S(qid) .. " 선택 보상 " .. (ok and S(n) or ("오류: " .. tostring(n))) .. "개")
    end
  end
end

local function CmdTraits()
  local function P(label, f)
    local ok, a, b, c = pcall(f)
    if not ok then Print("  " .. label .. " 오류: " .. tostring(a)) return nil end
    Print("  " .. label .. ": " .. S(a) .. ((b ~= nil) and (" / " .. S(b)) or "") .. ((c ~= nil) and (" / " .. S(c)) or ""))
    return a
  end
  if C_SpecializationInfo then
    local n = P("전문화 개수", function() return C_SpecializationInfo.GetNumSpecializations and C_SpecializationInfo.GetNumSpecializations() or "함수없음" end)
    for i = 1, (tonumber(n) or 0) do
      P("전문화 " .. i, function() return C_SpecializationInfo.GetSpecializationInfo(i) end)
    end
    P("현재 전문화 번호", function() return C_SpecializationInfo.GetSpecialization() end)
  end
  local cfg
  if C_ClassTalents then
    cfg = P("활성 설정 번호", function() return C_ClassTalents.GetActiveConfigID() end)
    P("특성 사용 가능", function() return C_ClassTalents.CanChangeTalents and C_ClassTalents.CanChangeTalents() end)
  end
  if C_Traits and cfg then
    local info = P("설정 정보", function() local c = C_Traits.GetConfigInfo(cfg) return c and c.name, c and c.type, c and c.treeIDs and #c.treeIDs end)
    local tree
    pcall(function() local c = C_Traits.GetConfigInfo(cfg) tree = c and c.treeIDs and c.treeIDs[1] end)
    if tree then
      local nodes = C_Traits.GetTreeNodes(tree)
      Print("  트리 " .. S(tree) .. " 노드 수: " .. S(nodes and #nodes))
      local spent, shown = 0, 0
      for _, id in ipairs(nodes or {}) do
        local okn, ni = pcall(C_Traits.GetNodeInfo, cfg, id)
        if okn and ni then
          local r = ni.currentRank or 0
          if r > 0 then
            spent = spent + r
            if shown < 12 then
              shown = shown + 1
              local nm = "?"
              pcall(function()
                local e = ni.activeEntry and ni.activeEntry.entryID or (ni.entryIDs and ni.entryIDs[1])
                local ei = C_Traits.GetEntryInfo(cfg, e)
                local di = C_Traits.GetDefinitionInfo(ei.definitionID)
                nm = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(di.spellID)) or tostring(di.spellID)
              end)
              Print("    노드 " .. S(id) .. " 랭크 " .. S(r) .. "/" .. S(ni.maxRanks) .. " " .. S(nm))
            end
          end
        end
      end
      Print("  투자한 포인트 합계: " .. spent)
      -- 노드가 어느 특성 줄기(탭)에 속하는지 구분할 수 있는지 확인
      local groups, order = {}, {}
      local ti
      pcall(function() ti = C_Traits.GetTreeInfo and C_Traits.GetTreeInfo(cfg, tree) end)
      if ti then
        local keys = {}
        for k, v in pairs(ti) do keys[#keys + 1] = tostring(k) .. "=" .. S(type(v) == "table" and "표" or v) end
        table.sort(keys)
        Print("  트리 정보: " .. table.concat(keys, ", "))
      end
      for _, id in ipairs(nodes or {}) do
        local okn, ni = pcall(C_Traits.GetNodeInfo, cfg, id)
        if okn and ni then
          local g = (ni.groupIDs and ni.groupIDs[1]) or "그룹없음"
          local t = groups[g]
          if not t then
            t = { n = 0, rank = 0, ymin = 99999, ymax = -99999, xmin = 99999, xmax = -99999 }
            groups[g] = t
            order[#order + 1] = g
          end
          t.n = t.n + 1
          t.rank = t.rank + (ni.currentRank or 0)
          local x, y = ni.posX, ni.posY
          if type(x) == "number" then
            if x < t.xmin then t.xmin = x end
            if x > t.xmax then t.xmax = x end
          end
          if type(y) == "number" then
            if y < t.ymin then t.ymin = y end
            if y > t.ymax then t.ymax = y end
          end
        end
      end
      for _, g in ipairs(order) do
        local t = groups[g]
        Print("  그룹 " .. S(g) .. ": 노드 " .. t.n .. "개 / 투자 " .. t.rank .. " / x " .. t.xmin .. "~" .. t.xmax .. " y " .. t.ymin .. "~" .. t.ymax)
      end
    end
  end
end

local auto = false
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
pcall(ev.RegisterEvent, ev, "QUEST_DETAIL")
pcall(ev.RegisterEvent, ev, "QUEST_COMPLETE")
pcall(ev.RegisterEvent, ev, "QUEST_PROGRESS")
ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" and a1 == "QuestNavigator" then
    QuestNavDB = QuestNavDB or {}
    auto = QuestNavDB.auto and true or false
    return
  end
  if auto and (e == "QUEST_COMPLETE" or e == "QUEST_DETAIL") then
    Print("이벤트 " .. e)
    Safe("quest", CmdQuest)
  end
end)

SLASH_QUESTNAV1 = "/qn"
SlashCmdList["QUESTNAV"] = function(msg)
  msg = msg or ""
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "api" then Safe("api", CmdApi)
  elseif cmd == "gear" then Safe("gear", CmdGear)
  elseif cmd == "talents" then Safe("talents", CmdTalents)
  elseif cmd == "traits" then Safe("traits", CmdTraits)
  elseif cmd == "item" then Safe("item", CmdItem, arg)
  elseif cmd == "quest" then Safe("quest", CmdQuest)
  elseif cmd == "auto" then
    auto = not auto
    QuestNavDB = QuestNavDB or {}
    QuestNavDB.auto = auto
    Print("퀘스트창 자동 읽기: " .. (auto and "켜짐" or "꺼짐"))
  else
    Print("명령: /qn api | gear | talents | traits | item <번호> | quest | auto")
  end
end
