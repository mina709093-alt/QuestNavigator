-- 업데이트 내역 (상수팩 업데이트 안내 창에 표시됨). 새 버전이 위로 오게 적습니다.
if not SangsuPack or not SangsuPack.RegisterChangelog then return end

SangsuPack:RegisterChangelog("QuestNavigator", {
  { ver = "0.3.4",
    "퀘스트를 받거나 완료할 때마다 뜨던 QN 로그를 기본으로 껐습니다. /qn 로그 로 켜고 끌 수 있습니다.",
  },
  { ver = "0.3.3",
    "퀘스트 보상을 확인할 때 나던 오류(GetNumQuestLogChoices)를 고쳤습니다.",
  },
}, "0.3.2")
