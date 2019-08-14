local orig_print = print
if Mods.mrudat_TestingMods then
  print = orig_print
else
  print = empty_func
end

local CurrentModId = rawget(_G, 'CurrentModId') or rawget(_G, 'CurrentModId_X')
local CurrentModDef = rawget(_G, 'CurrentModDef') or rawget(_G, 'CurrentModDef_X')
if not CurrentModId then

  -- copied shamelessly from Expanded Cheat Menu
  local Mods, rawset = Mods, rawset
  for id, mod in pairs(Mods) do
    rawset(mod.env, "CurrentModId_X", id)
    rawset(mod.env, "CurrentModDef_X", mod)
  end

  CurrentModId = CurrentModId_X
  CurrentModDef = CurrentModDef_X
end

orig_print("loading", CurrentModId, "-", CurrentModDef.title)

local function FixResupplyItemDefinitions()
  local sponsor = g_CurrentMissionParams and g_CurrentMissionParams.idMissionSponsor or ""
  local mods = GetSponsorModifiers(sponsor)
  local locks = GetSponsorLocks(sponsor)
  local idx = 0
  ForEachPreset("Cargo", function(item, group, self, props)
    local find = table.find(ResupplyItemDefinitions, "id", item.id)
    if not find then
      local def = setmetatable({}, {__index = item})
      local mod = mods[def.id] or 0
      if mod ~= 0 then
        ModifyResupplyDef(def, "price", mod)
      end
      local lock = locks[def.id]
      if lock ~= nil then
        def.locked = lock
      end
      if type(def.verifier) == "function" then
        def.locked = def.locked or not def.verifier(def, sponsor)
      end
      idx =  idx +1
      table.insert(ResupplyItemDefinitions, idx, def)
    end
  end)
end

local function AddPrefabs()
  print("BuyMorePrefabs.AddPrefabs")
  local ingredients = Presets.Cargo["Basic Resources"]
  local prefabs = Presets.Cargo.Prefabs
  local locked = Presets.Cargo.Locked
  local const_prop_prefix = 'construction_cost_'

  local ingredient_lookup = {}

  for id, ingredient in pairs(ingredients) do

    if ingredient.id == id then
      ingredient_lookup[id] = {
        prop_id = const_prop_prefix .. ingredient.id,
        item_weight = ingredient.kg / ingredient.pack,
        item_price = ingredient.price / ingredient.pack
      }
    end
  end

  local function GetBuildingCosts(building)
    local total_weight = 0
    local total_price = 0
    for id, data in pairs(ingredient_lookup) do
      local item_count = building[data.prop_id]
      if item_count and item_count > 0 then
        print(id, item_count / 1000.0, data.item_weight, data.item_price)
        total_weight = total_weight + data.item_weight * item_count / 1000
        total_price = total_price + data.item_price * item_count / 1000
      end
    end
    total_price = MulDivRound(total_price, 120, 100)
    print("totals", total_weight, total_price)
    return total_weight, total_price
  end

  function AddPrefab(building)
    local id = building.id
    print("Considering adding prefab for building: ", id)
    if locked[id] then
      print("Prefab already exists, but is locked")
      return
    end
    if prefabs[id] then
      print("Prefab already exists.")
      return
    end
    print("Adding prefab for building")
    local building_weight, building_price = GetBuildingCosts(building)
    if building_weight == 0 then
      print("Can't find any ingredients, not building prefab.")
      return
    end
    local prefab = PlaceObj('Cargo', {
      SortKey = building.SortKey or 17001000,
      description = building.description,
      group = "Prefabs",
      icon = building.display_icon,
      id = id,
      kg = building_weight,
      name = building.display_name,
      price = building_price,
    })
    print(prefab)
  end

  local buildings = BuildingTemplates
  for id, building in pairs(buildings) do
    if building.require_prefab then
      AddPrefab(building)
    end
  end

  FixResupplyItemDefinitions()
end

-- this is too late to be included in the rocket menu.
--OnMsg.LoadGame = AddPrefabs()
--OnMsg.CityStart = AddPrefabs()
--OnMsg.ClassesPostprocess = AddPrefabs()

-- this breaks the build menu.
--[[
local orig_RocketPayload_Init = RocketPayload_Init
function RocketPayload_Init()
  orig_RocketPayload_Init()
  AddPrefabs()
end
]]

-- this also breaks the build menu.

local orig_RocketPayloadObjectCreateAndLoad = RocketPayloadObjectCreateAndLoad
function RocketPayloadObjectCreateAndLoad(pregame)
  if not pregame then
    AddPrefabs()
  end
  return orig_RocketPayloadObjectCreateAndLoad(pregame)
end

orig_print("loaded", CurrentModId, "-", CurrentModDef.title)
