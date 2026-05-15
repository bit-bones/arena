math.randomseed(os.time())

-- Clear console function
function clear_console()
    -- Attempt to clear the console.  On Unix-like systems use "clear";
    -- on Windows systems, "cls" may be required.  os.execute returns
    -- system-dependent values which we ignore.
    -- Use package.config to detect path separator: Windows uses '\\'
    if package and package.config and package.config:sub(1,1) == "\\" then
        os.execute("cls")
    else
        os.execute("clear")
    end
end

-- Clear only for major transitions (not during combat)
function clear_for_transition()
    clear_console()
end

-- Player definition
-- Pending message to display when the player flees to the shop.  This
-- will be set when a flee action occurs and then consumed upon
-- entering the shop.  It allows us to show how much damage the
-- monster inflicted during the escape before showing the shop menu.
pending_flee_message = nil

player = {
    name = "You",
    level = 1,
    hp = 100,
    max_hp = 100,
    xp = 0,
    power = 0,
    defense = 0,
    accuracy = 0,
    dodge = 0,
    health_potions = 0,
    stamina_potions = 0,
    coins = 20,
    inshop = false,
    inventory = {},
    -- Inventory management system
    max_inventory = 5,            -- Starting inventory limit
    temp_items = {},              -- Items obtained during arena runs (not equipped yet)
    inventory_upgrades = 0,
    health_potion_upgrades = 0,
    stamina_potion_upgrades = 0,
    evasion_potion_upgrades = 0,
    evasion_bonus_active = false, -- Temporary shop bonus from using upgraded evasion potion
    -- Number of evasion potions carried.  These allow a safe escape
    -- from combat.
    evasion_potions = 0,
    -- Current stamina.  Certain actions (strong attacks, healing
    -- abilities) consume stamina.  Stamina regenerates after each
    -- player action by stamina_regen.
    stamina = 10,
    max_stamina = 10,
    stamina_regen = 1,
    -- Ability flags unlocked by unique boss items.  heal_ability
    -- grants access to a self‑heal action that consumes stamina, and
    -- lifesteal_ability siphons a portion of damage dealt back as HP.
    heal_ability = false,
    lifesteal_ability = false,
    -- Blood Strike ability flag.  This is granted by a shrine event and
    -- allows the player to sacrifice HP and stamina for a powerful
    -- strike with increased stats and a temporary dodge boost.
    blood_strike_ability = false,
    -- Temporary dodge bonus applied during special attacks like Blood
    -- Strike.  This bonus is consumed after the next enemy attack.
    temp_dodge_bonus = 0,
    -- Flag used for backstab.  When true the next enemy attack is
    -- automatically dodged regardless of dodge cap.  It resets after
    -- being consumed.
    guaranteed_dodge_next = false,
    --
    -- Sneak stat: determines how likely you are to enter a new room
    -- without the monsters noticing.  Each point of sneak grants
    -- roughly +1% chance to start an encounter undetected.  At 100
    -- sneak you will always be hidden on entry.  While hidden you
    -- gain access to special stealth actions.
    sneak = 5,
    --
    -- Luck stat: influences the quality and quantity of loot found
    -- throughout the game.  Each point of luck slightly increases
    -- coin rewards and the chances of uncommon/rare equipment in
    -- shops and monster drops.  Luck starts at 0 but can be
    -- increased through skills and items.
    luck = 0,
    --
    -- Skill points: earned on level up.  Rather than raising your
    -- core stats automatically, you can allocate these points in
    -- various skill sets to permanently customize your character.
    skill_points = 0,

    --
    -- Table to track how many points have been invested into each
    -- skill set.  These values are referenced when displaying the
    -- skill menu.  When allocating a point, both this table and
    -- the player's base stats are updated.
    skills = {
        Fighter = 0,
        Elusive = 0,
        Focus = 0,
        Fortitude = 0,
        Assassin = 0,
        Tank = 0,
        Lucky = 0,
        Berserk = 0,
        ["Blood Oath"] = 0,
        Radiance = 0
    },
    -- Blood mark indicates the player has made a blood pact with the
    -- shrine.  When true, further visits to the shrine grant
    -- additional blood abilities without requiring another sacrifice.
    bloodmark = false,
    -- Paladin mark indicates the player has been blessed by a paladin
    -- encounter.  When true, the Radiance skill tree becomes
    -- available.
    paladinmark = false,
    -- Blood abilities unlocked by the shrine.  Blood Strike exists
    -- already on blood_strike_ability.  These flags control
    -- availability of additional blood powers.
    blood_drain_ability = false,
    blood_boil_ability = false,
    -- Track remaining turns of the Blood Boil buff.  While greater
    -- than zero, the player gains temporary bonuses.
    blood_boiling_turns = 0,
    -- Paladin abilities unlocked by the paladin encounter.
    paladin_light_ability = false,
    reflect_ability = false,
    clarity_ability = false,
    -- Reflect tracking: when reflect is active, the next enemy attack
    -- will be partially negated and reflected.
    reflect_active = false,
    reflect_percent = 0,
    -- Merchant item counters.  These track how many stacks of each
    -- merchant upgrade the player owns.  They influence shop item
    -- counts, potion effects, and pricing.
    extra_stock = 0,
    health_potion_upgrade = 0,
    stamina_potion_upgrade = 0,
    evasion_potion_upgrade = 0,
    merchant_bangle = 0,

    -- Active status counters for certain abilities
    -- When Shield Wall is active (Tank skill ability), this counter
    -- indicates how many incoming monster attacks will be reduced.  Each
    -- point represents one turn of 50% damage reduction.  The counter
    -- is decremented after each enemy attack.
    shield_wall_turns = 0,
    -- When Holy Aura is active (Radiance skill ability), this counter
    -- Holy Aura turns - tracks how long the player benefits from a 30% damage
    -- reduction.  Like shield wall, it is decremented after each
    -- enemy attack.
    holy_aura_turns = 0,
    -- Blinded status - player attacks automatically miss while blinded
    blinded_turns = 0,
    -- Jackpot flag used by the Lucky skill ability.  When true, the
    -- next monster kill will grant double coin rewards and guarantee
    -- an item drop.  It resets automatically after a kill.
    jackpot_active = false,
    -- New Blood Ritual system - demands a sacrifice (enemy or player death)
    blood_ritual_active = false,        -- Whether ritual is currently active
    blood_ritual_persistent = false,    -- Whether ritual is in persistent mode (drains HP each turn)
    blood_ritual_stacks = 0,            -- Number of stacks accumulated (each gives +1 power/accuracy, +5 sneak, -1 defense)
    blood_ritual_completed_before = false, -- Whether player has completed a ritual before (for cultist encounter)
    -- Track bonus amounts directly instead of original stats for easier cleanup
    blood_ritual_power_bonus = 0,
    blood_ritual_sneak_bonus = 0,
    blood_ritual_defense_bonus = 0,
    blood_ritual_maxhp_bonus = 0,
    
    -- Holy Ritual system - similar to Blood Ritual but for the Paladin path
    holy_ritual_active = false,        -- Whether holy ritual is currently active
    holy_ritual_persistent = false,    -- Whether ritual is in persistent mode
    holy_ritual_stacks = 0,            -- Number of stacks accumulated (each gives +1 defense, +5 max HP, -1 power, -5 sneak)
    holy_ritual_completed_before = false, -- Whether player has completed a holy ritual before
    -- Track bonus amounts directly instead of original stats for easier cleanup
    holy_ritual_defense_bonus = 0,
    holy_ritual_maxhp_bonus = 0,
    holy_ritual_power_bonus = 0,
    holy_ritual_sneak_bonus = 0,
    
    -- Cultist equipment effects
    blood_ability_cost_reduction = 0,  -- Reduces stamina costs for blood abilities

    -- Ability management system - tracks which abilities are enabled/disabled
    abilities_enabled = {
        attack = true,           -- Normal attack - always available
        strong_attack = true,    -- Strong attack
        blood_strike = false,    -- Unlocked by shrine events
        heal = false,            -- Unlocked by boss items
        blood_drain = false,     -- Blood ability
        blood_boil = false,      -- Blood ability
        paladin_light = false,   -- Paladin ability
        reflect = false,         -- Paladin ability
        clarity = false,         -- Paladin ability
        -- Skill abilities (unlocked at 5 points in each skill set)
        shield_bash = false,     -- Fighter skill ability
        shadow_step = false,     -- Elusive skill ability
        meditate = false,        -- Focus skill ability
        second_wind = false,     -- Fortitude skill ability
        poisoned_strike = false, -- Assassin skill ability
        shield_wall = false,     -- Tank skill ability
        jackpot = false,         -- Lucky skill ability
        frenzy = false,          -- Berserk skill ability
        blood_ritual = false,    -- Blood Oath skill ability
        holy_ritual = false,     -- Radiance skill ability
    },

    -- Maximum number of abilities player can bring to arena (excludes potions)
    max_abilities = 4,

    -- Total XP earned (separate from current XP for leveling)
    total_xp = 0,

    -- Progress tracking for death screen statistics
    total_items_obtained = 0,     -- Total items collected/purchased (never decreases)
    total_abilities_unlocked = 2, -- Starts at 2 for attack and strong attack
    skill_sets_learned = 0,       -- Number of skill sets with enough points to unlock abilities
    total_damage_dealt = 0,       -- Total damage dealt to monsters
    total_damage_taken = 0,       -- Total damage taken from monsters

    -- Monster kill tracking
    monster_kills = {
        Bat = 0,
        Goblin = 0,
        Skeleton = 0,
        Slime = 0,
        Worm = 0
    },

    -- Boss kill tracking
    boss_kills = {
        ["Goblin King"] = 0,
        ["Slime Lord"] = 0,
        ["Skeleton Warrior"] = 0,
        ["Vampire Bat"] = 0,
        ["Giant Worm"] = 0
    }

    ,
    -- Whether the Focus skill tree has been unlocked.  Focus starts
    -- locked and is revealed only after meeting the scholar and
    -- paying his one‑time fee.  This mirrors the lock behaviour for
    -- Blood Oath and Radiance which are gated behind other events.
    focus_unlocked = false,
    -- Whether the player has already paid the scholar.  After
    -- payment the scholar no longer requests the fee and his shop
    -- becomes permanently available.
    scholar_paid = false,
    -- Tracking which skill books have been purchased.  Each entry in
    -- this table is keyed by the skill name and set to true when the
    -- corresponding book is purchased from the scholar.  A purchased
    -- book increases the maximum points that can be invested into
    -- that skill set from 5 to 10.
    skill_books = {},
    
    -- Blood cult tracking - whether cultists have been encountered at shrine
    cultists_encountered = false,
    
    -- Paladin hostility tracking - whether paladins are permanently hostile
    paladins_hostile = false,
    
    -- Flag for immediate paladin combat (when Blood Ritual is used on a paladin)
    immediate_paladin_combat = false
}

-- Unique boss loot definitions.  Defeating a boss grants a
-- guaranteed special item that reflects the boss's theme.  These
-- items provide powerful bonuses and may unlock special abilities.
boss_unique_items = {
    ["Goblin King"] = {
        name = "Goblin King's Crown",
        power_bonus = 4,
        accuracy_bonus = 2,
        description = "+4 Power, +2 Accuracy"
    },
    ["Slime Lord"] = {
        name = "Slime Core",
        max_hp_bonus = 20,
        description = "+20 Max HP (Grants Heal Ability)",
        grant_heal = true
    },
    ["Skeleton Warrior"] = {
        name = "Skeleton Shield",
        defense_bonus = 10,
        dodge_bonus = -5,
        description = "+10 Defense, -5 Dodge"
    },
    ["Vampire Bat"] = {
        name = "Vampire Cloak",
        dodge_bonus = 20,
        description = "+20 Dodge (Grants Lifesteal)",
        grant_lifesteal = true
    },
    ["Giant Worm"] = {
        name = "Worm Plate",
        defense_bonus = 8,
        max_hp_bonus = 30,
        description = "+8 Defense, +30 Max HP"
    }
}

--
-- Skill system definitions.  Each skill set entry contains a
-- description used in the menu and a function that applies the
-- permanent effects for a single point investment.  When adding
-- additional skill sets here, be sure to update the `skills` table
-- in the player definition accordingly.
skill_definitions = {
    {
        name = "Fighter",
        icon = "👊",
        description = "(+1 Power, +1 Defense)",
        apply = function()
            player.power = player.power + 1
            player.defense = player.defense + 1
        end
    },
    {
        name = "Elusive",
        icon = "🕶",
        description = "(+15 Sneak/Dodge, +1 Stamina Regen)",
        apply = function()
            player.dodge = player.dodge + 15
            player.sneak = player.sneak + 15
            player.stamina_regen = player.stamina_regen + 1
        end
    },
    {
        name = "Focus",
        icon = "🧠",
        description = "(+1 Accuracy, +1 Stamina Regen, +5 Dodge)",
        apply = function()
            player.accuracy = player.accuracy + 1
            player.stamina_regen = player.stamina_regen + 1
            player.dodge = player.dodge + 5
        end
    },
    {
        name = "Fortitude",
        icon = "🧱",
        description = "(+5 Max HP, +1 Max Stamina, +2 Defense)",
        apply = function()
            player.max_hp = player.max_hp + 5
            player.hp = player.hp + 5
            if player.hp > player.max_hp then player.hp = player.max_hp end
            player.max_stamina = player.max_stamina + 1
            player.stamina = player.stamina + 1
            if player.stamina > player.max_stamina then player.stamina = player.max_stamina end
            player.defense = player.defense + 2
        end
    },
    {
        name = "Assassin",
        icon = "🔪",
        description = "(+2 Power/Accuracy, +10 Sneak, -2 Defense)",
        apply = function()
            player.power = player.power + 2
            player.accuracy = player.accuracy + 2
            player.sneak = player.sneak + 10
            player.defense = player.defense - 2
        end
    },
    {
        name = "Lucky",
        icon = "🍀",
        description = "(+2 Luck, +1 Accuracy, +5 Dodge)",
        apply = function()
            player.luck = player.luck + 2
            player.accuracy = player.accuracy + 1
            player.dodge = player.dodge + 5
        end
    },
    {
        name = "Berserk",
        icon = "💣",
        description = "(+3 Power, +1 Max Stamina, -3 Accuracy)",
        apply = function()
            player.power = player.power + 3
            player.max_stamina = player.max_stamina + 1
            player.stamina = player.stamina + 1
            if player.stamina > player.max_stamina then player.stamina = player.max_stamina end
            player.accuracy = player.accuracy - 3
        end
    },
    {
        name = "Blood Oath",
        icon = "🩸",
        description = "(+2 Power, -10 Max HP, +1 Max Stamina)",
        apply = function()
            player.power = player.power + 2
            player.max_hp = player.max_hp - 10
            if player.hp > player.max_hp then player.hp = player.max_hp end
            player.stamina = player.stamina + 1
            if player.stamina > player.max_stamina then player.stamina = player.max_stamina end
        end
    },
    {
        name = "Radiance",
        icon = "✨",
        description = "(+2 Defense, +10 Max HP, +1 Max Stamina/Stamina Regen)",
        apply = function()
            player.defense = player.defense + 2
            player.max_hp = player.max_hp + 10
            player.hp = player.hp + 10
            if player.hp > player.max_hp then player.hp = player.max_hp end
            player.max_stamina = player.max_stamina + 1
            player.stamina = player.stamina + 1
            if player.stamina > player.max_stamina then player.stamina = player.max_stamina end
            player.stamina_regen = player.stamina_regen + 1
        end
    }
}

--
-- Determine the maximum number of points that can be invested into a
-- given skill set.  By default all skill sets are capped at 5
-- points.  Purchasing a corresponding book from the scholar raises
-- that cap to 10 for the selected skill.  The player.skill_books
-- table stores which books have been bought.  This helper returns
-- either 5 or 10 accordingly.
function get_skill_cap(skill_name)
    if player.skill_books and player.skill_books[skill_name] then
        return 10
    else
        return 5
    end
end

--
-- Unlock additional investment for a skill set.  When the player
-- purchases a skill book from the scholar this function marks the
-- skill as expanded in the player.skill_books table.  It prints a
-- confirmation so the player knows they can now invest up to ten
-- points into that skill.  If called for a skill that is already
-- expanded it has no additional effect.
function player:unlock_skill_book(skill_name)
    if not self.skill_books[skill_name] then
        self.skill_books[skill_name] = true
        print("📚 You study the tome and unlock deeper understanding of the " .. skill_name .. " skill set!")
        print("You may now invest up to 10 points in " .. skill_name .. ".")
    else
        -- Already unlocked; no message
    end
end

-- Stat information system - provides detailed explanations for each stat
function show_stat_info(stat_number)
    clear_console()

    if stat_number == 1 then -- Power
        print("💪 Power - Increases maximum damage dealt")
        print("========================================")
        print("Current Level: " .. player.power)
        print("")
        print("Logic & Scaling:")
        print("• Base damage = random(minimum, power)")
        print("• Minimum damage = 5 + accuracy")
        print("• Each point increases maximum damage by 1")
        print("• Strong Attack adds +5 power temporarily")
        print("• Items and abilities can boost power further")
        print("")
        print("Example: Power 15 = damage range 5-15 per hit")
    elseif stat_number == 2 then -- Defense
        print("🛡️ Defense - Reduces damage taken")
        print("=================================")
        print("Current Level: " .. player.defense)
        print("")
        print("Logic & Scaling:")
        print("• Damage taken = max(1, incoming_damage - defense)")
        print("• Each point reduces damage by 1 (minimum 1)")
        print("• Shield Wall (Tank skill) adds 50% reduction")
        print("• Some abilities provide temporary defense boosts")
        print("")
        print("Example: Defense 5 vs 10 damage = 5 damage taken")
    elseif stat_number == 3 then -- Accuracy
        print("🎯 Accuracy - Increases minimum damage and hit chance")
        print("===================================================")
        print("Current Level: " .. player.accuracy)
        print("")
        print("Logic & Scaling:")
        print("• Hit chance = random(1,20) + accuracy/2 vs enemy dodge")
        print("• Minimum damage = 5 + accuracy")
        print("• Higher accuracy = more consistent damage")
        print("• Critical for reliable hits against fast enemies")
        print("")
        print("Example: Accuracy 10 = minimum 15 damage, +5 hit bonus")
    elseif stat_number == 4 then -- Dodge
        print("💨 Dodge - Increases chance of dodging attacks")
        print("============================================")
        print("Current Level: " .. player.dodge)
        print("")
        print("Logic & Scaling:")
        print("• Dodge chance = random(1,10) + dodge vs enemy hit")
        print("• Each point increases dodge chance")
        print("• Capped at reasonable levels to prevent invincibility")
        print("• Some abilities provide temporary dodge bonuses")
        print("")
        print("Example: Dodge 15 = good chance to avoid attacks")
    elseif stat_number == 5 then -- Sneak
        print("🕵️ Sneak - Increases chance of entering arena undetected")
        print("======================================================")
        print("Current Level: " .. player.sneak)
        print("")
        print("Logic & Scaling:")
        print("• Stealth entry chance = sneak% vs detection")
        print("• Enables special stealth abilities in combat")
        print("• Reduces flee damage when escaping")
        print("• Higher sneak = better stealth options")
        print("")
        print("Example: Sneak 50 = 50% chance to enter undetected")
    elseif stat_number == 6 then -- Luck
        print("🍀 Luck - Increases chance of finding rare items and coins")
        print("=======================================================")
        print("Current Level: " .. player.luck)
        print("")
        print("Logic & Scaling:")
        print("• Bonus coins = random(0, luck) per monster kill")
        print("• Improves item drop rates and rarity chances")
        print("• Affects pickpocket success and loot quality")
        print("• Each point = 1 extra coin potential per kill")
        print("")
        print("Example: Luck 10 = 0-10 bonus coins per kill")
    elseif stat_number == 7 then -- Max HP
        print("❤️ Max HP - Increases maximum health points")
        print("=========================================")
        print("Current Level: " .. player.max_hp)
        print("")
        print("Logic & Scaling:")
        print("• Base 100 HP at level 1")
        print("• Gains +10 HP per level up")
        print("• Items can provide permanent HP bonuses")
        print("• Some abilities cost HP but provide benefits")
        print("")
        print("Example: Level 5 = 140 max HP (100 + 40 from levels)")
    elseif stat_number == 8 then -- Max Stamina
        print("⚡ Max Stamina - Increases maximum stamina points")
        print("===============================================")
        print("Current Level: " .. player.max_stamina)
        print("")
        print("Logic & Scaling:")
        print("• Base 10 stamina at level 1")
        print("• Gains +1 stamina per level up")
        print("• Required for special abilities and strong attacks")
        print("• Items can provide permanent stamina bonuses")
        print("")
        print("Example: Level 5 = 14 max stamina (10 + 4 from levels)")
    elseif stat_number == 9 then -- Stamina Regen
        print("♻️ Stamina Regen - Increases stamina regeneration rate")
        print("===================================================")
        print("Current Level: " .. player.stamina_regen)
        print("")
        print("Logic & Scaling:")
        print("• Stamina restored per turn = stamina_regen")
        print("• Base regeneration is 2 per turn")
        print("• Skills and items can increase regeneration")
        print("• Critical for ability-heavy combat styles")
        print("")
        print("Example: Regen 4 = regain 4 stamina each turn")
    end

    print("")
    io.write("Press Enter to return to Stats...")
    local _ = io.read()
end

-- New Stats screen - shows current stats with monster/boss kill counts
function show_stats_screen()
    while true do
        clear_console()
        print("📊 Stats | " ..
        player.name ..
        " | Level " ..
        player.level .. " | Total XP: \27[34m⬆️  " .. player.total_xp .. "\27[0m | 🌟 " .. player.skill_points)
        print("")

        -- Display stats with current values
        print("1. | " .. player.power .. " | 💪 Power (Increases maximum damage dealt)")
        print("2. | " .. player.defense .. " | 🛡️ Defense (Reduces damage taken)")
        print("3. | " .. player.accuracy .. " | 🎯 Accuracy (Increases minimum damage and chance to hit)")
        print("4. | " .. player.dodge .. " | 💨 Dodge (Increases chance of dodging attacks)")
        print("5. | " .. player.sneak .. " | 🕵️ Sneak (Increases chance of entering the arena undetected)")
        print("6. | " .. player.luck .. " | 🎲 Luck (Increases chance of finding rare items and more coins)")
        print("7. | " .. player.max_hp .. " |❤️  Max HP (Increases maximum health points)")
        print("8. | " .. player.max_stamina .. " | ⚡ Max Stamina (Increases maximum stamina points)")
        print("9. | " .. player.stamina_regen .. " | ♻️  Stamina Regen (Increases stamina regeneration rate)")
        print("")

        -- Display monster kill counts
        for monster_type, count in pairs(player.monster_kills or {}) do
            print("| " .. count .. " | " .. monster_type .. "s killed")
        end

        -- Display boss kill counts (only if any bosses have been killed)
        local boss_displays = {}
        for boss_name, count in pairs(player.boss_kills or {}) do
            if count > 0 then
                -- Extract monster type from boss name (e.g., "Goblin King" -> "Goblins")
                local monster_type = string.match(boss_name, "^(%w+)")
                if monster_type then
                    table.insert(boss_displays,
                        "| " ..
                        (player.monster_kills[monster_type] or 0) .. " | " .. monster_type .. "s killed     | Boss: " .. count)
                end
            end
        end

        -- Show boss kills in place of regular monster displays if any exist
        if #boss_displays > 0 then
            print("")
            for _, display in ipairs(boss_displays) do
                print(display)
            end
        end

        print("")
        print("0. 📚 Return to Skill Sets")
        print("Press Enter to see your Abilities 🧬")
        print("")
        io.write("Choose a Stat number for more information: ")

        local choice = io.read()
        if choice == nil then choice = "" end

        -- Check for restart input
        if check_restart_input(choice) then
            return "restart"
        end

        if choice == "" then
            return "abilities"
        elseif choice == "0" then
            return "skills"
        else
            local stat_num = tonumber(choice)
            if stat_num and stat_num >= 1 and stat_num <= 9 then
                show_stat_info(stat_num)
            else
                clear_console()
                print("❌ Invalid choice! Press Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Abilities management screen (accessible from shop/stats)
function show_abilities_screen()
    while true do
        clear_console()
        print("🧬 Abilities | " .. player.name .. " | Level " .. player.level .. " | 🌟 " .. player.skill_points)
        print("")

        local ability_count = 0
        local ability_list = {}

        -- Always show basic attacks
        ability_count = ability_count + 1
        local attack_status = player.abilities_enabled.attack and "🟢" or "🔴"
        print(ability_count .. ". " .. attack_status .. "  🗡 Attack (Your normal attack)")
        table.insert(ability_list, "attack")

        ability_count = ability_count + 1
        local strong_status = player.abilities_enabled.strong_attack and "🟢" or "🔴"
        print(ability_count .. ". " .. strong_status .. "  💪 Strong Attack (-3 Stamina | +5 Power, -3 Defense)")
        table.insert(ability_list, "strong_attack")

        -- Show unlocked special abilities
        if player.blood_strike_ability then
            ability_count = ability_count + 1
            local blood_status = player.abilities_enabled.blood_strike and "🟢" or "🔴"
            print(ability_count ..
            ". " .. blood_status .. "  🩸 Blood Strike (-20 HP, -8 Stamina | +8 Power/Accuracy, +50 Dodge)")
            table.insert(ability_list, "blood_strike")
        end

        if player.heal_ability then
            ability_count = ability_count + 1
            local heal_status = player.abilities_enabled.heal and "🟢" or "🔴"
            print(ability_count .. ". " .. heal_status .. "  ✨ Heal (-5 Stamina | Restore 20 HP)")
            table.insert(ability_list, "heal")
        end

        -- Add blood abilities
        if player.blood_drain_ability then
            ability_count = ability_count + 1
            local blood_drain_status = player.abilities_enabled.blood_drain and "🟢" or "🔴"
            print(ability_count .. ". " .. blood_drain_status .. "  🩸 Blood Drain (-5 Stamina | Steal 10 HP)")
            table.insert(ability_list, "blood_drain")
        end

        if player.blood_boil_ability then
            ability_count = ability_count + 1
            local blood_boil_status = player.abilities_enabled.blood_boil and "🟢" or "🔴"
            print(ability_count ..
            ". " .. blood_boil_status .. "  🔥 Blood Boil (-20 HP | +10 Stamina, +5 Power/Accuracy for 2 attacks)")
            table.insert(ability_list, "blood_boil")
        end

        -- Add paladin abilities
        if player.paladin_light_ability then
            ability_count = ability_count + 1
            local paladin_status = player.abilities_enabled.paladin_light and "🟢" or "🔴"
            print(ability_count ..
            ". " .. paladin_status .. "  ✨ Paladin's Light (-10 Stamina | Blind enemy & heal 10 HP)")
            table.insert(ability_list, "paladin_light")
        end

        if player.reflect_ability then
            ability_count = ability_count + 1
            local reflect_status = player.abilities_enabled.reflect and "🟢" or "🔴"
            print(ability_count ..
            ". " .. reflect_status .. "  🔰 Reflect (-8 Stamina | Negate & reflect damage next turn)")
            table.insert(ability_list, "reflect")
        end

        if player.clarity_ability then
            ability_count = ability_count + 1
            local clarity_status = player.abilities_enabled.clarity and "🟢" or "🔴"
            print(ability_count ..
            ". " .. clarity_status .. "  🧘 Clarity (-8 Stamina | +5 Power/Accuracy/Defense attack)")
            table.insert(ability_list, "clarity")
        end

        -- Add skill abilities (check if unlocked by having 5+ points in the skill set)
        if (player.skills["Fighter"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.shield_bash and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  👊 Shield Bash (-3 Stamina | Stun enemy for 1 turn)")
            table.insert(ability_list, "shield_bash")
        end

        if (player.skills["Elusive"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.shadow_step and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  🕶 Shadow Step (-5 Stamina | Guaranteed dodge next turn)")
            table.insert(ability_list, "shadow_step")
        end

        if (player.skills["Focus"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.meditate and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  🧠 Meditate (-3 Stamina | Restore 5 stamina)")
            table.insert(ability_list, "meditate")
        end

        if (player.skills["Fortitude"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.second_wind and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  🧱 Second Wind (-5 Stamina | Heal 15 HP)")
            table.insert(ability_list, "second_wind")
        end

        if (player.skills["Assassin"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.poisoned_strike and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  ☠️ Poisoned Strike (-4 Stamina | Poison enemy for 2 turns)")
            table.insert(ability_list, "poisoned_strike")
        end

        if (player.skills["Tank"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.shield_wall and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  🛡️ Shield Wall (-6 Stamina | 50% damage reduction for 3 turns)")
            table.insert(ability_list, "shield_wall")
        end

        if (player.skills["Lucky"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.jackpot and "🟢" or "🔴"
            print(ability_count ..
            ". " .. status .. "  🍀 Jackpot (-10 Stamina | Bonus coins & extra drop chance next kill)")
            table.insert(ability_list, "jackpot")
        end

        if (player.skills["Berserk"] or 0) >= 5 then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.frenzy and "🟢" or "🔴"
            print(ability_count .. ". " .. status .. "  💣 Frenzy (-8 Stamina | Attack twice this turn)")
            table.insert(ability_list, "frenzy")
        end

        if (player.skills["Blood Oath"] or 0) >= 5 and player.bloodmark then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.blood_ritual and "🟢" or "🔴"
            local stack_info = ""
            if player.blood_ritual_stacks > 0 then
                stack_info = " (🩸" .. player.blood_ritual_stacks .. " stacks)"
            else
                stack_info = player.blood_ritual_persistent and " (ACTIVE -20❤️/turn)" or ""
            end
            print(ability_count .. ". " .. status .. "  🩸 Blood Ritual" .. stack_info .. " | Build permanent power stacks")
            table.insert(ability_list, "blood_ritual")
        end

        if (player.skills["Radiance"] or 0) >= 5 and player.paladinmark then
            ability_count = ability_count + 1
            local status = player.abilities_enabled.holy_ritual and "🟢" or "🔴"
            local stack_info = ""
            if player.holy_ritual_stacks > 0 then
                stack_info = " (✨" .. player.holy_ritual_stacks .. " stacks)"
            else
                stack_info = player.holy_ritual_persistent and " (ACTIVE)" or ""
            end
            print(ability_count .. ". " .. status .. "  ✨ Holy Ritual" .. stack_info .. " | Build permanent defense stacks")
            table.insert(ability_list, "holy_ritual")
        end

        -- Add more abilities as they exist in the system
        -- This will automatically expand as new abilities are added

        -- Count and display enabled abilities
        local enabled_count = count_enabled_abilities()
        print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
        print("🧬 Enabled Abilities: " .. enabled_count .. "/" .. player.max_abilities .. 
              (enabled_count > player.max_abilities and " \27[31m(TOO MANY!)\27[0m" or ""))
        
        print("")
        print("0. 📊 Return to Stats")
        print("Press Enter to return to the shop 🏪")
        print("")
        io.write("Choose an ability number to enable/disable it: ")

        local choice = io.read()
        if choice == nil then choice = "" end

        -- Check for restart input
        if check_restart_input(choice) then
            return "restart"
        end

        if choice == "" then
            return "shop"
        elseif choice == "0" then
            return "stats"
        else
            local ability_num = tonumber(choice)
            if ability_num and ability_num >= 1 and ability_num <= #ability_list then
                local ability_key = ability_list[ability_num]
                
                -- Special handling for basic abilities (always enabled)
                if ability_key == "attack" then
                    print("⚠️ Normal Attack cannot be disabled!")
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                    return
                end
                
                -- Toggle ability status with limit checking
                if not player.abilities_enabled[ability_key] then
                    -- Trying to enable an ability
                    if count_enabled_abilities() >= player.max_abilities and ability_key ~= "strong_attack" then
                        clear_console()
                        print("⚠️ You can only have " .. player.max_abilities .. " abilities enabled at once!")
                        print("Disable another ability first before enabling this one.")
                        io.write("\nPress Enter to continue...")
                        local _ = io.read()
                    else
                        player.abilities_enabled[ability_key] = true
                    end
                else
                    -- Disabling an ability
                    player.abilities_enabled[ability_key] = false
                end
            else
                clear_console()
                print("❌ Invalid choice! Press Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Arena abilities view (read-only, accessed with ".." during combat)
function show_arena_abilities()
    clear_console()
    print("🧬 Abilities | " .. player.name .. " | Level " .. player.level .. " | 🌟 " .. player.skill_points)
    print("")

    -- Show all abilities with their status (enabled/disabled)
    local count = 0

    -- Always show basic attacks
    count = count + 1
    local attack_status = player.abilities_enabled.attack and "🟢" or "🔴"
    print(count .. ". " .. attack_status .. "  🗡 Attack (Your normal attack)")

    count = count + 1
    local strong_status = player.abilities_enabled.strong_attack and "🟢" or "🔴"
    print(count .. ". " .. strong_status .. "  💪 Strong Attack (-3 Stamina | +5 Power, -3 Defense)")

    -- Show unlocked special abilities
    if player.blood_strike_ability then
        count = count + 1
        local blood_status = player.abilities_enabled.blood_strike and "🟢" or "🔴"
        print(count .. ". " .. blood_status .. "  🩸 Blood Strike (-20 HP, -8 Stamina | +8 Power/Accuracy, +50 Dodge)")
    end

    if player.heal_ability then
        count = count + 1
        local heal_status = player.abilities_enabled.heal and "🟢" or "🔴"
        print(count .. ". " .. heal_status .. "  ✨ Heal (-5 Stamina | Restore 20 HP)")
    end

    -- Add blood abilities
    if player.blood_drain_ability then
        count = count + 1
        local blood_drain_status = player.abilities_enabled.blood_drain and "🟢" or "🔴"
        print(count .. ". " .. blood_drain_status .. "  🩸 Blood Drain (-5 Stamina | Steal 10 HP)")
    end

    if player.blood_boil_ability then
        count = count + 1
        local blood_boil_status = player.abilities_enabled.blood_boil and "🟢" or "🔴"
        print(count ..
        ". " .. blood_boil_status .. "  � Blood Boil (-20 HP | +10 Stamina, +5 Power/Accuracy for 2 attacks)")
    end

    -- Add paladin abilities
    if player.paladin_light_ability then
        count = count + 1
        local paladin_status = player.abilities_enabled.paladin_light and "🟢" or "🔴"
        print(count .. ". " .. paladin_status .. "  ✨ Paladin's Light (-10 Stamina | Blind enemy & heal 10 HP)")
    end

    if player.reflect_ability then
        count = count + 1
        local reflect_status = player.abilities_enabled.reflect and "🟢" or "🔴"
        print(count .. ". " .. reflect_status .. "  🔰 Reflect (-8 Stamina | Negate & reflect damage next turn)")
    end

    if player.clarity_ability then
        count = count + 1
        local clarity_status = player.abilities_enabled.clarity and "🟢" or "🔴"
        print(count .. ". " .. clarity_status .. "  🧘 Clarity (-8 Stamina | +5 Power/Accuracy/Defense attack)")
    end

    -- Add skill abilities (show all unlocked ones with status)
    if (player.skills["Fighter"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.shield_bash and "🟢" or "🔴"
        print(count .. ". " .. status .. "  👊 Shield Bash (-3 Stamina | Stun enemy for 1 turn)")
    end

    if (player.skills["Elusive"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.shadow_step and "🟢" or "🔴"
        print(count .. ". " .. status .. "  � Shadow Step (-5 Stamina | Guaranteed dodge next turn)")
    end

    if (player.skills["Focus"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.meditate and "🟢" or "🔴"
        print(count .. ". " .. status .. "  🧠 Meditate (-3 Stamina | Restore 5 stamina)")
    end

    if (player.skills["Fortitude"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.second_wind and "🟢" or "🔴"
        print(count .. ". " .. status .. "  🧱 Second Wind (-5 Stamina | Heal 15 HP)")
    end

    if (player.skills["Assassin"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.poisoned_strike and "🟢" or "🔴"
        print(count .. ". " .. status .. "  ☠️ Poisoned Strike (-4 Stamina | Poison enemy for 2 turns)")
    end

    if (player.skills["Tank"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.shield_wall and "🟢" or "🔴"
        print(count .. ". " .. status .. "  🛡️ Shield Wall (-6 Stamina | 50% damage reduction for 3 turns)")
    end

    if (player.skills["Lucky"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.jackpot and "🟢" or "🔴"
        print(count .. ". " .. status .. "  🍀 Jackpot (-10 Stamina | Bonus coins & extra drop chance next kill)")
    end

    if (player.skills["Berserk"] or 0) >= 5 then
        count = count + 1
        local status = player.abilities_enabled.frenzy and "🟢" or "🔴"
        print(count .. ". " .. status .. "  💣 Frenzy (-8 Stamina | Attack twice this turn)")
    end

    if (player.skills["Blood Oath"] or 0) >= 5 and player.bloodmark then
        count = count + 1
        local status = player.abilities_enabled.blood_ritual and "🟢" or "🔴"
        local stack_info = ""
        if player.blood_ritual_stacks > 0 then
            stack_info = " (🩸" .. player.blood_ritual_stacks .. " stacks)"
        else
            stack_info = player.blood_ritual_persistent and " (ACTIVE -20❤️/turn)" or ""
        end
        print(count .. ". " .. status .. "  🩸 Blood Ritual" .. stack_info .. " | Build permanent power stacks")
    end

    if (player.skills["Radiance"] or 0) >= 5 and player.paladinmark then
        count = count + 1
        local status = player.abilities_enabled.holy_ritual and "🟢" or "🔴"
        local stack_info = ""
        if player.holy_ritual_stacks > 0 then
            stack_info = " (✨" .. player.holy_ritual_stacks .. " stacks)"
        else
            stack_info = player.holy_ritual_persistent and " (ACTIVE)" or ""
        end
        print(count .. ". " .. status .. "  ✨ Holy Ritual" .. stack_info .. " | Build permanent defense stacks")
    end

    print("")
    print("Press Enter to return to the Arena: ⚔️")
    print("")
    local _ = io.read()
end

-- Updated Skills menu to match new format
function open_skills_menu()
    while true do
        clear_console()
        print("📚 Skill Sets | Level " .. player.level .. " | Skill Points: 🌟 " .. player.skill_points)
        print("")

        -- Display each skill with current investment level
        local available_skills = {}
        local skill_index = 1
        for i, skill in ipairs(skill_definitions) do
            local should_show = true

            -- Hide Blood Oath if player doesn't have bloodmark
            if skill.name == "Blood Oath" and not player.bloodmark then
                should_show = false
            end

            -- Hide Radiance if player doesn't have paladinmark
            if skill.name == "Radiance" and not player.paladinmark then
                should_show = false
            end

            -- Hide Focus until the scholar has been met and paid.  Focus
            -- starts locked like Blood Oath and Radiance.
            if skill.name == "Focus" and not player.focus_unlocked then
                should_show = false
            end

            if should_show then
                local invested = player.skills[skill.name] or 0
                print(skill_index ..
                ". | " .. invested .. " | " .. skill.icon .. " " .. skill.name .. " " .. skill.description)
                available_skills[skill_index] = skill
                skill_index = skill_index + 1
            end
        end

        print("")
        -- Display current stats summary
        print("💪  " .. player.power .. "  | 🛡️  " .. player.defense .. " | 🎯  " .. player.accuracy)
        print("💨  " .. player.dodge .. "  | 🕵️  " .. player.sneak .. " | 🍀  " .. player.luck)
        print("❤️  " .. player.max_hp .. " | ⚡  " .. player.max_stamina .. " | ♻️  " .. player.stamina_regen)
        print("")
        print("0. 💼 Return to Inventory")
        print("Enter to see Stats information 📊")
        print("")
        io.write("Choose a Skill Set number to invest points: ")

        local choice = io.read()
        if choice == nil then choice = "" end

        -- Check for restart input
        if check_restart_input(choice) then
            return "restart"
        end

        if choice == "" then
            -- Go to stats screen
            local result = show_stats_screen()
            if result == "abilities" then
                local result2 = show_abilities_screen()
                if result2 == "shop" then
                    return "shop"
                elseif result2 == "restart" then
                    return "restart"
                elseif result2 == "stats" then
                    -- Continue in stats loop
                    show_stats_screen()
                end
            elseif result == "skills" then
                -- Continue in skills loop
            elseif result == "restart" then
                return "restart"
            end
        elseif choice == "0" then
            return "inventory"
        else
            local idx = tonumber(choice)
            if not idx or idx < 1 or idx > #available_skills then
                clear_console()
                print("❌ Invalid selection! Press Enter to continue...")
                local _ = io.read()
            else
                if player.skill_points <= 0 then
                    clear_console()
                    print("❌ You have no skill points to spend! Press Enter to continue...")
                    local _ = io.read()
                else
                    local skill = available_skills[idx]
                    -- Check if this skill has reached its current cap
                    local invested_points = player.skills[skill.name] or 0
                    local cap = get_skill_cap(skill.name)
                    if invested_points >= cap then
                        clear_console()
                        print("❌ You cannot invest further in this skill set.")
                        if cap == 5 then
                            print("The " .. skill.name .. " skill set is currently capped at 5 points.")
                        else
                            print("You have already invested the maximum of 10 points in this skill.")
                        end
                        io.write("\nPress Enter to continue...")
                        local _ = io.read()
                    else
                        -- Apply the skill's effect
                        skill.apply()
                        -- Deduct a skill point and increment investment count
                        player.skill_points = player.skill_points - 1
                        player.skills[skill.name] = invested_points + 1

                        -- Check if player just unlocked a skill ability (at exactly 5 points)
                        local new_points = player.skills[skill.name]
                        if new_points == 5 then
                            local ability_name = ""
                            local ability_key = ""
                            if skill.name == "Fighter" then
                                ability_name = "Shield Bash"
                                ability_key = "shield_bash"
                            elseif skill.name == "Elusive" then
                                ability_name = "Shadow Step"
                                ability_key = "shadow_step"
                            elseif skill.name == "Focus" then
                                ability_name = "Meditate"
                                ability_key = "meditate"
                            elseif skill.name == "Fortitude" then
                                ability_name = "Second Wind"
                                ability_key = "second_wind"
                            elseif skill.name == "Assassin" then
                                ability_name = "Poisoned Strike"
                                ability_key = "poisoned_strike"
                            elseif skill.name == "Tank" then
                                ability_name = "Shield Wall"
                                ability_key = "shield_wall"
                            elseif skill.name == "Lucky" then
                                ability_name = "Jackpot"
                                ability_key = "jackpot"
                            elseif skill.name == "Berserk" then
                                ability_name = "Frenzy"
                                ability_key = "frenzy"
                            elseif skill.name == "Blood Oath" then
                                ability_name = "Blood Ritual"
                                ability_key = "blood_ritual"
                            elseif skill.name == "Radiance" then
                                ability_name = "Holy Aura"
                                ability_key = "holy_aura"
                            end

                            clear_console()
                            print("✅ Invested 1 point into " .. skill.name .. "!")
                            if ability_name ~= "" then
                                print("")
                                player:unlock_ability(ability_name)
                                -- Enable the ability in the abilities system
                                player.abilities_enabled[ability_key] = true
                                print("🎉 You've mastered the " .. skill.name .. " skill set!")
                                print("")
                            end
                        else
                            clear_console()
                            print("✅ Invested 1 point into " .. skill.name .. "!")
                        end
                        io.write("Press Enter to continue...")
                        local _ = io.read()
                    end
                end
            end
        end
    end
end

tips = {
    "💡 Slimes have the ability to regen health!.",
    "💡 Skeletons have strong armor!.",
    "💡 Goblins have increased power!.",
    "💡 Bats have increased dodge and an accurate counter-attack!.",
    "💡 Worms have highly resistant hide!.",
    "💡 Bosses have multiple attacks!.",
}

-- Return an emoji representing an item's rarity.  This helper is
-- used when printing item names outside of the shop so that the
-- player can easily recognize the quality of dropped and stolen
-- equipment.
function get_rarity_symbol(rarity)
    if rarity == "rare" then
        return "🔶"
    elseif rarity == "uncommon" then
        return "🔷"
    elseif rarity == "common" then
        return "🟤"
    elseif rarity == "cursed" then
        return "🔻"
    else
        return ""
    end
end

function player:attack(target)
    -- Blinded players automatically miss
    if self.blinded_turns and self.blinded_turns > 0 then
        return false, 0, "😵 You are blinded and miss!"
    end
    
    local hit_chance = math.random(1, 20) + math.floor(self.accuracy / 2)
    local dodge_chance = math.random(1, 10) + (target.level or 1)
    if hit_chance <= dodge_chance then
        return false
    end

    local min_dmg = math.max(1, 5 + self.accuracy)
    local max_dmg = math.max(min_dmg, self.power)
    local dmg = math.random(min_dmg, max_dmg)
    
    -- Apply Divine Shield damage reduction for hostile paladins
    if target.is_paladin and target.divine_shield_turns and target.divine_shield_turns > 0 then
        dmg = math.ceil(dmg * 0.2) -- Divine Shield blocks 80% of damage
    end
    
    target.hp = target.hp - dmg

    -- Skeleton loses stamina when taking damage (based on damage dealt)
    if target.name == "Skeleton" and target.stamina and target.stamina > 0 then
        local stamina_drain = math.floor(dmg / 3) -- 1 stamina per 3 damage
        if stamina_drain > 0 then
            target.stamina = math.max(0, target.stamina - stamina_drain)
        end
    end

    -- If the player has a lifesteal ability, heal a portion of the
    -- damage dealt.  Lifesteal heals for half of the damage inflicted.
    if self.lifesteal_ability and dmg > 0 then
        local heal = math.floor(dmg / 2)
        self.hp = math.min(self.max_hp, self.hp + heal)
    end
    return true, dmg
end

function player:strong_attack(target)
    -- Blinded players automatically miss
    if self.blinded_turns and self.blinded_turns > 0 then
        return false, 0, "😵 You are blinded and miss!"
    end
    
    local hit_chance = math.random(1, 20) + math.floor(self.accuracy / 2)
    local dodge_chance = math.random(1, 10) + (target.level or 1)
    if hit_chance <= dodge_chance then
        return false
    end

    local min_dmg = math.max(1, 5 + self.accuracy)
    local max_dmg = math.max(min_dmg, self.power + 3)
    local dmg = math.random(min_dmg, max_dmg)
    
    -- Apply Divine Shield damage reduction for hostile paladins
    if target.is_paladin and target.divine_shield_turns and target.divine_shield_turns > 0 then
        dmg = math.ceil(dmg * 0.2) -- Divine Shield blocks 80% of damage
    end
    
    local temp_defense = self.defense
    -- strong attack temporarily reduces your defense
    self.defense = self.defense - 3
    target.hp = target.hp - dmg
    self.defense = temp_defense
    -- Apply lifesteal on strong attacks as well
    if self.lifesteal_ability and dmg > 0 then
        local heal = math.floor(dmg / 2)
        self.hp = math.min(self.max_hp, self.hp + heal)
    end
    return true, dmg
end

--
-- Adds the given amount of experience to the player.  This function only
-- handles the internal state changes and returns whether a level‑up
-- occurred.  It does not print anything so that callers can decide
-- how to display XP gains and level‑up messages (for example,
-- clearing the screen and showing a concise reward summary after a fight).
--
-- Award experience to the player and handle level ups.  The amount of
-- XP required to gain the next level increases by 10 for each new
-- level (100 at level 1, 110 at level 2, etc.).  When a level up
-- occurs the player gains +10 maximum HP and +1 maximum stamina and
-- heals for 50% of their new maximums.  Instead of automatically
-- boosting combat stats, the player receives one skill point per
-- level which can be spent in the skill menu.
function player:gain_xp(amount)
    -- accumulate experience
    self.xp = self.xp + amount
    -- Track total XP earned
    self.total_xp = self.total_xp + amount
    local level_up = false
    -- determine the XP threshold for the current level
    local xp_needed = 100 + (self.level - 1) * 10
    -- continue leveling up while enough XP has been accumulated
    while self.xp >= xp_needed do
        self.xp = self.xp - xp_needed
        self.level = self.level + 1
        level_up = true
        -- Increase maximum HP and heal for 50% of the new max
        self.max_hp = self.max_hp + 10
        local heal_amount = math.floor(self.max_hp * 0.5)
        self.hp = math.min(self.max_hp, self.hp + heal_amount)
        -- Increase maximum stamina and restore 50% of it
        self.max_stamina = self.max_stamina + 1
        local stamina_heal = math.floor(self.max_stamina * 0.5)
        self.stamina = math.min(self.max_stamina, self.stamina + stamina_heal)
        -- Award one skill point
        self.skill_points = self.skill_points + 1
        -- Update XP threshold for the next level
        xp_needed = 100 + (self.level - 1) * 10
    end
    return level_up
end

-- Helper function to track ability unlocks for death screen statistics
function player:unlock_ability(ability_name)
    self.total_abilities_unlocked = self.total_abilities_unlocked + 1
    print("🧬 New ability unlocked: " .. ability_name .. "! (Total: " .. self.total_abilities_unlocked .. ")")
end

-- Helper function to calculate how many skill sets have unlocked their abilities
function player:calculate_skill_sets_learned()
    local learned = 0
    local skill_sets = { "Fighter", "Elusive", "Focus", "Fortitude", "Assassin", "Tank", "Lucky", "Berserk", "Blood Oath",
        "Radiance" }

    for _, skill_name in ipairs(skill_sets) do
        local points = self.skills[skill_name] or 0
        -- Special cases for marked abilities
        if skill_name == "Blood Oath" and not self.bloodmark then
            -- Can't learn Blood Oath without bloodmark
        elseif skill_name == "Radiance" and not self.paladinmark then
            -- Can't learn Radiance without paladin mark
        elseif points >= 5 then
            learned = learned + 1
        end
    end

    return learned
end

-- Add item to temporary storage during arena runs (no stat bonuses applied)
function player:add_temp_item(item)
    -- Track total items obtained for death screen statistics
    self.total_items_obtained = self.total_items_obtained + 1

    -- Add to temporary items list (no stat bonuses applied yet)
    table.insert(self.temp_items, item)

    local symbol = get_rarity_symbol(item.rarity)
    print("📦 " .. symbol .. " " .. item.name .. " found! (Will be equipped when you return to shop)")
end

function player:add_item(item)
    -- Insert the item into the player's inventory.  Items are always
    -- stored regardless of whether they provide stats or merchant
    -- upgrades.  Display the rarity symbol alongside the name for
    -- easy recognition outside of the shop.

    -- Handle upgrade items specially - they apply their effect and don't take inventory space
    -- Exception: Merchant's Bangle stays as an item since it can be sold
    -- Skill books unlock additional points in a specific skill set.  When
    -- purchased from the scholar they should not take up inventory
    -- space.  Instead, applying their effect here upgrades the
    -- corresponding skill cap.
    if item.skill_book_for then
        self:unlock_skill_book(item.skill_book_for)
        return
    end

    if item.inventory_upgrade then
        self.max_inventory = self.max_inventory + item.inventory_upgrade
        self.inventory_upgrades = self.inventory_upgrades + item.inventory_upgrade
        print("📈 Inventory capacity increased to " .. self.max_inventory .. " items!")
        return
    end

    if item.health_potion_upgrade_bonus then
        self.health_potion_upgrades = self.health_potion_upgrades + item.health_potion_upgrade_bonus
        print("💊 Health potions upgraded! +" ..
        item.health_potion_upgrade_bonus .. " bonus (Total: +" .. self.health_potion_upgrades .. ")")
        return
    end

    if item.stamina_potion_upgrade_bonus then
        self.stamina_potion_upgrades = self.stamina_potion_upgrades + item.stamina_potion_upgrade_bonus
        print("⚡ Stamina potions upgraded! +" ..
        item.stamina_potion_upgrade_bonus .. " bonus (Total: +" .. self.stamina_potion_upgrades .. ")")
        return
    end

    if item.evasion_potion_upgrade_bonus then
        self.evasion_potion_upgrades = self.evasion_potion_upgrades + item.evasion_potion_upgrade_bonus
        print("🧪  Evasion potions upgraded! Shop discounts improved (Total: +" .. self.evasion_potion_upgrades .. ")")
        return
    end

    table.insert(self.inventory, item)

    -- Handle merchant bangle effect (stays as item but applies effect)
    if item.merchant_bangle_bonus then
        self.merchant_bangle = self.merchant_bangle + item.merchant_bangle_bonus
        print("💼 Merchant's Bangle equipped! Shop discounts and sell bonuses active!")
    end

    -- Handle cultist robes special effect
    if item.blood_ability_cost_reduction then
        self.blood_ability_cost_reduction = (self.blood_ability_cost_reduction or 0) + item.blood_ability_cost_reduction
        print("🔻 Cultist Robes equipped! Blood abilities cost " .. item.blood_ability_cost_reduction .. " less stamina!")
    end

    -- Track total items obtained for death screen statistics
    self.total_items_obtained = self.total_items_obtained + 1

    local symbol = get_rarity_symbol(item.rarity)
    -- Apply standard stat bonuses if present.  Negative values are
    -- also applied here so penalties take immediate effect.
    self.power = self.power + (item.power_bonus or 0)
    self.defense = self.defense + (item.defense_bonus or 0)
    self.accuracy = self.accuracy + (item.accuracy_bonus or 0)
    self.dodge = self.dodge + (item.dodge_bonus or 0)
    self.sneak = self.sneak + (item.sneak_bonus or 0)
    self.luck = self.luck + (item.luck_bonus or 0)
    -- Update max HP and fully heal when increasing maximum.
    if item.max_hp_bonus then
        self.max_hp = self.max_hp + item.max_hp_bonus
        self.hp = self.max_hp
    end
    -- Update max stamina and refill.
    if item.max_stamina_bonus then
        self.max_stamina = self.max_stamina + item.max_stamina_bonus
        self.stamina = self.max_stamina
    end
    -- Apply stamina regeneration bonus.
    if item.stamina_regen_bonus then
        self.stamina_regen = self.stamina_regen + item.stamina_regen_bonus
    end
    -- Merchant upgrade handling.  Some items grant persistent passive
    -- effects instead of combat stats.  These fields are checked
    -- individually and modify the appropriate player counters.
    if item.extra_stock_bonus then
        self.extra_stock = self.extra_stock + item.extra_stock_bonus
    end
    -- Items that reach here get added to inventory and apply their stats
    -- No special upgrade handling needed here since upgrade items return early

    -- Notify the player of the acquired item and its effects.  Both
    -- positive and negative modifiers are explicitly called out so
    -- penalties are not overlooked.  The rarity symbol always
    -- prefixes the item name so the player can quickly gauge
    -- quality whenever an item is referenced outside the shop.
    print("✅ " .. symbol .. " " .. item.name .. " added to inventory!")
    if item.power_bonus and item.power_bonus ~= 0 then
        local amt = math.abs(item.power_bonus)
        if item.power_bonus > 0 then
            print("  💪 Power increased by " .. amt)
        else
            print("  💪 Power decreased by " .. amt)
        end
    end
    if item.defense_bonus and item.defense_bonus ~= 0 then
        local amt = math.abs(item.defense_bonus)
        if item.defense_bonus > 0 then
            print("  🛡️  Defense increased by " .. amt)
        else
            print("  🛡️  Defense decreased by " .. amt)
        end
    end
    if item.accuracy_bonus and item.accuracy_bonus ~= 0 then
        local amt = math.abs(item.accuracy_bonus)
        if item.accuracy_bonus > 0 then
            print("  🎯 Accuracy increased by " .. amt)
        else
            print("  🎯 Accuracy decreased by " .. amt)
        end
    end
    if item.max_hp_bonus and item.max_hp_bonus ~= 0 then
        local amt = math.abs(item.max_hp_bonus)
        if item.max_hp_bonus > 0 then
            print("  ❤️  Max HP increased by " .. amt)
        else
            print("  ❤️  Max HP decreased by " .. amt)
        end
    end
    if item.dodge_bonus and item.dodge_bonus ~= 0 then
        local amt = math.abs(item.dodge_bonus)
        if item.dodge_bonus > 0 then
            print("  🌀 Dodge increased by " .. amt)
        else
            print("  🌀 Dodge decreased by " .. amt)
        end
    end
    if item.max_stamina_bonus and item.max_stamina_bonus ~= 0 then
        local amt = math.abs(item.max_stamina_bonus)
        if item.max_stamina_bonus > 0 then
            print("  ⚡ Max Stamina increased by " .. amt)
        else
            print("  ⚡ Max Stamina decreased by " .. amt)
        end
    end
    if item.stamina_regen_bonus and item.stamina_regen_bonus ~= 0 then
        local amt = math.abs(item.stamina_regen_bonus)
        if item.stamina_regen_bonus > 0 then
            print("  ♻️  Stamina Regen increased by " .. amt)
        else
            print("  ♻️  Stamina Regen decreased by " .. amt)
        end
    end
end

-- Sell an item from the player's inventory.  Returns true and the
-- amount gained if successful, or false and an error message if not.
-- Selling removes the item's bonuses from the player and refunds
-- half of the original purchase price.  Items without a price (e.g.
-- boss drops) cannot be sold.
function player:sell_item(index)
    local item = self.inventory[index]
    if not item then
        return false, "Invalid item number."
    end
    -- Items without a price are considered unsellable (e.g. boss loot)
    if not item.price then
        return false, "You cannot sell " .. item.name .. "."
    end
    -- Determine sell price (half, rounded down) with bonuses from merchant bangle only
    local base_sell_price = math.floor(item.price / 2)
    local sell_bonus = player.merchant_bangle       -- Only permanent bangle bonus affects selling
    local bonus_multiplier = 1 + (sell_bonus * 0.1) -- 10% increase per upgrade
    local sell_price = math.floor(base_sell_price * bonus_multiplier)
    -- Remove stat bonuses
    if item.power_bonus then
        self.power = self.power - item.power_bonus
    end
    if item.defense_bonus then
        self.defense = self.defense - item.defense_bonus
    end
    if item.accuracy_bonus then
        self.accuracy = self.accuracy - item.accuracy_bonus
    end
    if item.dodge_bonus then
        self.dodge = self.dodge - item.dodge_bonus
    end
    if item.max_hp_bonus then
        self.max_hp = self.max_hp - item.max_hp_bonus
        -- Adjust current HP if it exceeds the new maximum
        if self.hp > self.max_hp then
            self.hp = self.max_hp
        end
    end
    if item.max_stamina_bonus then
        self.max_stamina = self.max_stamina - item.max_stamina_bonus
        if self.stamina > self.max_stamina then
            self.stamina = self.max_stamina
        end
    end
    if item.stamina_regen_bonus then
        self.stamina_regen = self.stamina_regen - item.stamina_regen_bonus
    end
    -- Remove merchant bangle effect if selling merchant bangle
    if item.merchant_bangle_bonus then
        self.merchant_bangle = self.merchant_bangle - item.merchant_bangle_bonus
        print("💼 Merchant's Bangle effect removed!")
    end
    -- Remove from inventory
    table.remove(self.inventory, index)
    -- Refund coins
    self.coins = self.coins + sell_price
    return true, sell_price, item.name
end

-- Move temporary items to main inventory and apply their stat bonuses
function player:equip_temp_items()
    if #self.temp_items == 0 then
        return
    end

    print("\n📦 Equipping items found during your arena run:")
    for _, item in ipairs(self.temp_items) do
        -- Add to main inventory and apply stat bonuses
        self:add_item(item)
    end

    -- Clear temp items
    self.temp_items = {}
    print("")
end

-- Check if player's inventory exceeds the limit before entering arena
function player:check_inventory_limit()
    if #self.inventory > self.max_inventory then
        return false
    end
    return true
end

function player:use_evasion_potion()
    if self.evasion_potions > 0 then
        -- Check if Blood Ritual is active - severe HP penalty
        if self.blood_ritual_active then
            self.evasion_potions = self.evasion_potions - 1
            self.inshop = true
            
            -- Calculate survival HP based on upgrades (10% + 10% per upgrade)
            local survival_percent = 10 + (self.evasion_potion_upgrades * 10)
            local survival_hp = math.floor(self.max_hp * survival_percent / 100)
            if survival_hp < 1 then survival_hp = 1 end
            
            self.hp = survival_hp
            print("💨 You escape with the Evasion Potion, but the Blood Ritual nearly kills you!")
            print("🩸 The ritual's wrath reduces you to " .. survival_hp .. " HP (" .. survival_percent .. "% of max)!")
            
            -- Still get shop bonus if upgraded
            if self.evasion_potion_upgrades > 0 then
                self.evasion_bonus_active = true
                print("✨ Upgraded evasion potion grants temporary shop discounts!")
            end
            
            return true
        end
        
        -- Normal evasion potion usage (no Blood Ritual active)
        self.evasion_potions = self.evasion_potions - 1
        self.inshop = true
        print("💨 Used Evasion Potion! You slip away safely to the shop!")

        -- Activate temporary shop bonus if player has evasion potion upgrades
        if self.evasion_potion_upgrades > 0 then
            self.evasion_bonus_active = true
            print("✨ Upgraded evasion potion grants temporary shop discounts!")
        end

        return true
    else
        print("❌ You don't have any Evasion Potions!")
        return false
    end
end

-- Item definitions
item_pool = {
    -- Common items (70% chance)
    {
        name = "Rusty Sword",
        rarity = "common",
        price = 25,
        power_bonus = 1,
        description = "+1 Power"
    },
    {
        name = "Wooden Shield",
        rarity = "common",
        price = 25,
        defense_bonus = 2,
        dodge_bonus = -5,
        description = "+2 Defense, -5 Dodge"
    },
    {
        name = "Simple Bow",
        rarity = "common",
        price = 20,
        accuracy_bonus = 1,
        description = "+1 Accuracy"
    },
    {
        name = "Cloth Hood",
        rarity = "common",
        price = 25,
        dodge_bonus = 5,
        sneak_bonus = 5,
        description = "+5 Dodge/Sneak"
    },
    {
        name = "Leather Boots",
        rarity = "common",
        price = 35,
        dodge_bonus = 10,
        defense_bonus = 1,
        description = "+10 Dodge, +1 Defense"
    },
    -- Uncommon items (25% chance)
    {
        name = "Steel Sword",
        rarity = "uncommon",
        price = 75,
        power_bonus = 3,
        description = "+3 Power"
    },
    {
        name = "Iron Shield",
        rarity = "uncommon",
        price = 85,
        defense_bonus = 4,
        sneak_bonus = -10,
        dodge_bonus = -10,
        description = "+4 Defense, -10 Dodge/Sneak"
    },
    {
        name = "Hunter's Bow",
        rarity = "uncommon",
        price = 60,
        accuracy_bonus = 3,
        description = "+3 Accuracy"
    },
    {
        name = "Battle Axe",
        rarity = "uncommon",
        price = 90,
        power_bonus = 4,
        accuracy_bonus = -1,
        description = "+4 Power, -1 Accuracy"
    },
    -- Uncommon dodge‑oriented apparel
    {
        name = "Agile Hood",
        rarity = "uncommon",
        price = 80,
        dodge_bonus = 20,
        defense_bonus = -1,
        description = "+20 Dodge, -1 Defense"
    },
    {
        name = "Swift Boots",
        rarity = "uncommon",
        price = 75,
        dodge_bonus = 20,
        defense_bonus = -1,
        description = "+20 Dodge, -1 Defense"
    },
    -- Rare items (5% chance)
    {
        name = "Dragon Blade",
        rarity = "rare",
        price = 200,
        power_bonus = 8,
        accuracy_bonus = 2,
        description = "+8 Power, +2 Accuracy"
    },
    {
        name = "Aegis Shield",
        rarity = "rare",
        price = 280,
        defense_bonus = 10,
        max_hp_bonus = 25,
        description = "+10 Defense, +25 Max HP"
    },
    {
        name = "Elven Bow",
        rarity = "rare",
        price = 180,
        accuracy_bonus = 7,
        power_bonus = 2,
        description = "+7 Accuracy, +2 Power"
    },
    -- Rare dodge and stamina items
    {
        name = "Cloak of Shadows",
        rarity = "rare",
        price = 220,
        dodge_bonus = 30,
        sneak_bonus = 30,
        defense_bonus = -3,
        accuracy_bonus = 2,
        description = "+30 Dodge/Sneak, -3 Defense, +2 Accuracy"
    },
    {
        name = "Phantom Boots",
        rarity = "rare",
        price = 190,
        dodge_bonus = 30,
        sneak_bonus = 30,
        defense_bonus = -2,
        description = "+30 Dodge/Sneak, -2 Defense"
    },
    {
        name = "Mystic Stone",
        rarity = "rare",
        price = 250,
        max_stamina_bonus = 5,
        stamina_regen_bonus = 1,
        luck_bonus = 2,
        description = "+5 Max Stamina, +1 Stamina Regen, +2 Luck"
    },

    -- Additional items to add variation and strategy.  These items
    -- expand the equipment pool across all rarities and encourage
    -- different playstyles.
    {
        name = "Training Gloves",
        rarity = "common",
        price = 20,
        power_bonus = 1,
        accuracy_bonus = 1,
        description = "+1 Power, +1 Accuracy"
    },
    {
        name = "Lucky Coin",
        rarity = "common",
        price = 40,
        luck_bonus = 1,
        dodge_bonus = 5,
        accuracy_bonus = 1,
        description = "+1 Luck, +5 Dodge"
    },
    {
        name = "Old Cloak",
        rarity = "common",
        price = 30,
        defense_bonus = 1,
        dodge_bonus = 5,
        sneak_bonus = 5,
        description = "+1 Defense, +5 Dodge/Sneak"
    },
    -- Uncommon additions
    {
        name = "Warhammer",
        rarity = "uncommon",
        price = 100,
        power_bonus = 5,
        accuracy_bonus = -1,
        description = "+5 Power, -1 Accuracy"
    },
    {
        name = "Spiked Shield",
        rarity = "uncommon",
        price = 95,
        defense_bonus = 10,
        dodge_bonus = -10,
        description = "+10 Defense, -10 dodge"
    },
    {
        name = "Reinforced Boots",
        rarity = "uncommon",
        price = 85,
        defense_bonus = 3,
        dodge_bonus = 10,
        description = "+3 Defense, +10 Dodge"
    },
    -- Rare additions
    {
        name = "Assassin's Dagger",
        rarity = "rare",
        price = 210,
        power_bonus = 4,
        accuracy_bonus = 5,
        sneak_bonus = 15,
        description = "+4 Power, +5 Accuracy, +15 Sneak"
    },
    {
        name = "Sacred Scroll",
        rarity = "rare",
        price = 250,
        max_hp_bonus = 10,
        max_stamina_bonus = 5,
        stamina_regen_bonus = 1,
        luck_bonus = 2,
        description = "+10 Max HP, +5 Max Stamina, +1 Stamina Regen, +2 Luck"
    },
    {
        name = "Champion's Chainmail",
        rarity = "rare",
        price = 250,
        defense_bonus = 15,
        power_bonus = 3,
        dodge_bonus = -10,
        sneak_bonus = -10,
        description = "+15 Defense, +3 Power, -10 Dodge/Sneak"
    }
}

-- Generate random shop items
function generate_shop_items()
    local items = {}
    -- Chances for rare and uncommon items scale with the player's luck.
    -- Each 2 points of luck adds roughly 1% chance for rare items up to
    -- a maximum of 20%.  Each point of luck adds 1% uncommon chance up
    -- to a maximum of 70%.  The remainder of the 100% total is used
    -- for common items.  Luck therefore shifts the distribution
    -- towards higher quality gear as it increases.
    local rare_base = 5
    local uncommon_base = 25
    local rare_chance = rare_base + math.floor(player.luck / 2)
    if rare_chance > 20 then rare_chance = 20 end
    local uncommon_chance = uncommon_base + player.luck
    if uncommon_chance > 70 then uncommon_chance = 70 end

    -- Keep track of names we've already selected to avoid duplicate
    -- items appearing in the shop at the same time.  Because the item
    -- pool contains many entries, the chance of an infinite loop is
    -- extremely low.  If an item is picked that we've already chosen,
    -- we simply roll again until a new name is found.
    local selected = {}
    for i = 1, 3 do
        local roll = math.random(100)
        local rarity_pool = {}
        if roll <= rare_chance then
            -- rare item selection
            for _, itm in ipairs(item_pool) do
                if itm.rarity == "rare" then
                    table.insert(rarity_pool, itm)
                end
            end
        elseif roll <= rare_chance + uncommon_chance then
            -- uncommon item selection
            for _, itm in ipairs(item_pool) do
                if itm.rarity == "uncommon" then
                    table.insert(rarity_pool, itm)
                end
            end
        else
            -- common item selection
            for _, itm in ipairs(item_pool) do
                if itm.rarity == "common" then
                    table.insert(rarity_pool, itm)
                end
            end
        end
        if #rarity_pool > 0 then
            -- Attempt to find a unique item by name
            local attempts = 0
            local candidate
            repeat
                candidate = rarity_pool[math.random(#rarity_pool)]
                attempts = attempts + 1
            until not selected[candidate.name] or attempts > 20
            -- Mark the selected name and insert into the list.  If we
            -- exceeded the attempt limit, we accept the last candidate to
            -- avoid infinite loops.
            selected[candidate.name] = true
            table.insert(items, candidate)
        end
    end
    return items
end

-- Monster generator with levels and special abilities
function generate_monster()
    local names = { "Goblin", "Slime", "Skeleton", "Bat", "Worm" }
    
    -- If paladins are hostile, add them to the possible enemy pool
    if player.paladins_hostile then
        table.insert(names, "Paladin")
    end
    
    local name = names[math.random(#names)]
    
    -- If a hostile paladin was selected, generate it using the special function
    if name == "Paladin" then
        return generate_paladin_enemy()
    end
    -- Select monster level using a weighted distribution.  Lower level
    -- monsters are more common when the player is low level.  We
    -- consider levels from 1 up to player.level+2.  The weight is
    -- highest for levels at or below the player's level and decreases
    -- for higher levels.  This reduces the likelihood of fighting
    -- very strong monsters at the start of the game.
    local max_level = math.max(1, player.level + 2)
    local weights = {}
    for lvl = 1, max_level do
        local diff = lvl - player.level
        -- Assign weights: same or lower levels get high weight, +1
        -- level gets moderate weight, higher levels get small weight.
        local w
        if diff <= 0 then
            -- Monsters at or below the player's level are common.
            w = 5
        elseif diff == 1 then
            -- Slightly higher level monsters are less frequent.
            w = 3
        else
            -- Much higher level monsters are rare when the player is
            -- low level.  Use a fractional weight to greatly reduce
            -- their odds of appearing early on.
            w = 0.5
        end
        table.insert(weights, w)
    end
    local total_weight = 0
    for _, w in ipairs(weights) do total_weight = total_weight + w end
    local pick = math.random() * total_weight
    local cumulative = 0
    local level = 1
    for idx, w in ipairs(weights) do
        cumulative = cumulative + w
        if pick <= cumulative then
            level = idx
            break
        end
    end

    -- Check if boss should spawn (every 10 kills of same type)
    if player.monster_kills and (player.monster_kills[name] or 0) >= 10 then
        player.monster_kills[name] = 0 -- Reset counter
        return generate_boss(name, level)
    end

    local base_hp = 25 + (level - 1) * 12
    local base_power = 8 + (level - 1) * 4
    local hp = base_hp + math.random(-3, 8)
    local power = base_power + math.random(-1, 4)
    -- Monster stamina scales with level: base 8 + 2 per level
    local base_stamina = 8 + (level - 1) * 2
    local stamina = base_stamina + math.random(-1, 2)
    -- Increase the baseline gold drop and scale it more aggressively
    -- with the monster's level.  Previously: random(3,8)+level*2.  Now:
    -- random between 5 and 12 plus 4 per level.
    local coinDrop = math.random(5, 12) + level * 4
    -- Scale experience rewards.  As the player climbs in levels it
    -- becomes harder to advance, so XP rewards are deliberately
    -- conservative.  The base amount is 30 plus 12 per monster level.
    -- This keeps level progression challenging and encourages longer
    -- play sessions.
    local xpDrop = 30 + level * 12

    -- Special abilities based on monster type
    local special_ability = ""
    if name == "Bat" then
        special_ability = "High dodge chance"
    elseif name == "Skeleton" then
        special_ability = "High defense while stamina remains"
        power = power - 2 -- Lower attack but higher defense
    elseif name == "Slime" then
        special_ability = "Regenerates HP (costs stamina)"
    elseif name == "Goblin" then
        special_ability = "Aggressive attacker"
        -- Remove the power boost here, we'll implement double attack instead
    elseif name == "Worm" then
        special_ability = "Thick hide (activates during combat)"
    end

    return {
        name = name,
        level = level,
        hp = hp,
        max_hp = hp,
        power = power,
        stamina = stamina,
        max_stamina = stamina,
        coinDrop = coinDrop,
        xpDrop = xpDrop,
        is_boss = false,
        special_ability = special_ability,
        -- New fields for special abilities
        thick_hide_turns = 0,   -- For worms
        thick_hide_used = false -- To track if worm has used ability
    }
end

-- Hostile Paladin generator (for when paladins become enemies)
function generate_paladin_enemy()
    -- Generate a high-level, powerful paladin enemy
    local level = math.random(8, 12) -- High level paladins
    local hp = math.random(120, 180) -- High HP
    local power = math.random(20, 30) -- High damage
    local stamina = math.random(25, 35) -- High stamina
    local defense = math.random(8, 15) -- Good defense
    local accuracy = math.random(85, 95) -- High accuracy
    local dodge = math.random(15, 25) -- Decent dodge
    local coinDrop = math.random(80, 120) + level * 8 -- Good coin rewards
    local xpDrop = 100 + level * 20 -- High XP rewards
    
    return {
        name = "Hostile Paladin",
        level = level,
        hp = hp,
        max_hp = hp,
        power = power,
        stamina = stamina,
        max_stamina = stamina,
        defense = defense,
        accuracy = accuracy,
        dodge = dodge,
        coinDrop = coinDrop,
        xpDrop = xpDrop,
        special_ability = "Divine Combat: Paladin's Light, Reflect, Clarity, Holy Aura",
        is_boss = false,
        is_paladin = true, -- Flag to identify paladin enemies
        
        -- Paladin-specific abilities (matching player ability names)
        paladin_light_ability = true,
        reflect_ability = true,
        clarity_ability = true,
        holy_aura_ability = true,
        
        -- Status tracking
        divine_shield_turns = 0,
        holy_aura_turns = 0
    }
end

-- Boss generator
function generate_boss(base_name, level)
    local boss_names = {
        Goblin = "Goblin King",
        Slime = "Slime Lord",
        Skeleton = "Skeleton Warrior",
        Bat = "Vampire Bat",
        Worm = "Giant Worm"
    }

    local name = boss_names[base_name]
    local hp = (50 + (level - 1) * 20) * 2
    local power = (12 + (level - 1) * 6) * 1.5
    -- Boss stamina is much higher than regular monsters
    local stamina = (15 + (level - 1) * 4) * 2
    -- Bosses now drop more gold and XP.  Increase the random component
    -- and scale with level.  Previously: (random(25,50)+level*8)*2.  Now:
    -- random between 30 and 60 plus 10 per level, all doubled.
    local coinDrop = (math.random(30, 60) + level * 10) * 2
    -- Increase XP reward from bosses.  Previously: (80 + level*20)*2.
    -- Now: base 100 plus 25 per level, doubled.
    local xpDrop = (100 + level * 25) * 2

    return {
        name = name,
        level = level,
        hp = hp,
        max_hp = hp,
        power = math.floor(power),
        stamina = stamina,
        max_stamina = stamina,
        coinDrop = coinDrop,
        xpDrop = xpDrop,
        is_boss = true,
        special_ability = "Boss: Multiple attacks",
        thick_hide_turns = 0,
        thick_hide_used = false
    }
end

-- Determine whether the player enters the next encounter undetected.
function roll_entry_sneak()
    -- Always succeed if sneak is 100 or higher
    if player.sneak >= 100 then
        return true
    end
    local roll = math.random(1, 100)
    return roll <= player.sneak
end

-- Random event: finding a treasure chest.  The chest contains a
-- single item or potion, with drop chances weighted by rarity.
local function chest_event()
    clear_console()
    print("🎁 You stumble upon a mysterious chest!\n")
    -- Determine what the chest contains.  Potions are far more common
    -- than equipment; rare items are very rare.
    local roll = math.random(1, 100)
    if roll <= 40 then
        -- Evasion potion (very common)
        player.evasion_potions = player.evasion_potions + 1
        print("🧪 Inside you find an Evasion Potion! Total: " .. player.evasion_potions)
    elseif roll <= 70 then
        -- Stamina potion (common)
        player.stamina_potions = player.stamina_potions + 1
        print("⚡ Inside you find a Stamina Potion! Total: " .. player.stamina_potions)
    elseif roll <= 85 then
        -- Health potion (less common)
        player.health_potions = player.health_potions + 1
        print("❤️  Inside you find a Health Potion! Total: " .. player.health_potions)
    elseif roll <= 95 then
        -- Uncommon equipment
        local pool = {}
        for _, itm in ipairs(item_pool) do
            if itm.rarity == "uncommon" then
                table.insert(pool, itm)
            end
        end
        if #pool > 0 then
            local drop = pool[math.random(#pool)]
            -- Prefix the name with a rarity symbol
            print("🗃️  The chest contained " ..
            get_rarity_symbol(drop.rarity) .. " " .. drop.name .. "! (" .. drop.description .. ")")
            player:add_temp_item(drop)
        else
            print("The chest was empty...")
        end
    else
        -- Rare equipment (very rare)
        local pool = {}
        for _, itm in ipairs(item_pool) do
            if itm.rarity == "rare" then
                table.insert(pool, itm)
            end
        end
        if #pool > 0 then
            local drop = pool[math.random(#pool)]
            print("✨ The chest contained " ..
            get_rarity_symbol(drop.rarity) .. " " .. drop.name .. "! (" .. drop.description .. ")")
            player:add_temp_item(drop)
        else
            print("The chest contained nothing of value.")
        end
    end
    io.write("\nPress Enter to continue...")
    local _ = io.read()
end

-- Blood Shop function
local function blood_shop()
    -- Track how many expansions player has bought
    local blood_shop_expansions = player.blood_shop_expansions or 0
    local base_items = 3
    local total_items = base_items + blood_shop_expansions
    
    -- Check if player has blood ritual stacks they can trade
    local can_trade_stacks = player.blood_ritual_stacks > 0
    
    -- Generate the item selection ONCE when entering the shop
    local pool_copy = {}
    for _, item in ipairs(blood_shop_pool) do
        -- Don't show items player has already bought
        local already_owned = false
        if item.name == "Blood Oath Tome" and player.skill_books and player.skill_books["Blood Oath"] then
            already_owned = true
        elseif item.name == "Cultist Robes" then
            -- Check if player already has cultist robes in inventory
            for _, inv_item in ipairs(player.inventory) do
                if inv_item.name == "Cultist Robes" then
                    already_owned = true
                    break
                end
            end
        end
        
        if not already_owned then
            table.insert(pool_copy, item)
        end
    end
    
    -- Select random items up to the limit (this stays the same for the entire visit)
    local selected_items = {}
    for i = 1, math.min(total_items, #pool_copy) do
        if #pool_copy > 0 then
            local idx = math.random(#pool_copy)
            table.insert(selected_items, pool_copy[idx])
            table.remove(pool_copy, idx)
        end
    end
    
    while true do
        clear_console()

        print("🔻 The cultists stand around the shrine silently...")
        print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
        print("")
        
        -- Display items (now using the fixed selection)
        for i, item in ipairs(selected_items) do
            local symbol = get_rarity_symbol(item.rarity)
            print(i .. ". " .. symbol .. " " .. item.name .. " - " .. item.description .. " - 🩸" .. item.hp_cost .. " HP")
        end
        
        print("")
        -- Calculate offering cost for display
        local offering_cost = player.level * 10
        local coin_reward = offering_cost
        print((#selected_items + 1) .. ". 💰 Blood Offering (-" .. offering_cost .. " HP, +" .. coin_reward .. " coins)")
        
        -- Add blood ritual stack trading option if player has stacks
        if can_trade_stacks then
            local stack_coins = player.blood_ritual_stacks * 5
            print((#selected_items + 2) .. ". 🩸 Trade Blood Stacks (Convert " .. player.blood_ritual_stacks .. " stacks to " .. stack_coins .. " coins)")
            print((#selected_items + 3) .. ". 🚪 Leave")
        else
            print((#selected_items + 2) .. ". 🚪 Leave")
        end
        print("")
        print("❤️  Current HP: " .. player.hp .. "/" .. player.max_hp)
        print("")
        
        io.write("Choose your sacrifice: ")
        local choice = io.read()
        local num = tonumber(choice)
        
        -- Determine the exit option number based on whether stack trading is available
        local exit_option = can_trade_stacks and #selected_items + 3 or #selected_items + 2
        local stack_trade_option = #selected_items + 2
        
        if not num or num < 1 or num > exit_option then
            print("\n❌ Invalid choice.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
        elseif num == #selected_items + 1 then
            -- Blood offering for coins
            local offering_cost = player.level * 10
            local coin_reward = offering_cost
            
            if player.hp > offering_cost then
                print("\n🩸 Offer " .. offering_cost .. " HP for " .. coin_reward .. " coins?")
                print("1. Yes")
                print("2. No")
                io.write("\nYour choice: ")
                local confirm = io.read()
                
                if confirm == "1" then
                    -- 1% chance to not take HP but still give coins
                    local lucky_roll = math.random(1, 100)
                    if lucky_roll == 1 then
                        player.coins = player.coins + coin_reward
                        print("\n🍀 The blood gods smile upon you! You receive the coins without sacrifice!")
                        print("💰 Gained " .. coin_reward .. " coins! Total: " .. player.coins)
                    else
                        player.hp = player.hp - offering_cost
                        player.coins = player.coins + coin_reward
                        print("\n🩸 You offer " .. offering_cost .. " HP and receive " .. coin_reward .. " coins!")
                        print("💰 Total coins: " .. player.coins)
                    end
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                end
            else
                print("\n❌ You don't have enough HP for this offering! (Need " .. offering_cost .. " HP)")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        elseif can_trade_stacks and num == stack_trade_option then
            -- Trade blood ritual stacks for coins
            local stack_coins = player.blood_ritual_stacks * 5
            
            print("\n🩸 Trade " .. player.blood_ritual_stacks .. " blood ritual stacks for " .. stack_coins .. " coins?")
            print("1. Yes")
            print("2. No")
            io.write("\nYour choice: ")
            local confirm = io.read()
            
            if confirm == "1" then
                -- Convert stacks to coins and reset bonuses
                player.coins = player.coins + stack_coins
                
                -- Reset all bonuses from stacks
                player.power = player.power - player.blood_ritual_power_bonus
                player.sneak = player.sneak - player.blood_ritual_sneak_bonus
                player.defense = player.defense - player.blood_ritual_defense_bonus
                player.max_hp = player.max_hp - player.blood_ritual_maxhp_bonus
                if player.hp > player.max_hp then player.hp = player.max_hp end
                
                -- Reset all blood ritual variables
                player.blood_ritual_stacks = 0
                player.blood_ritual_power_bonus = 0
                player.blood_ritual_sneak_bonus = 0
                player.blood_ritual_defense_bonus = 0
                player.blood_ritual_maxhp_bonus = 0
                
                print("\n🩸 The Shrine accepts, and will remember your service...")
                print("💰 Gained " .. stack_coins .. " coins! Total: " .. player.coins)
                print("⚠️  Your blood ritual bonuses have been removed!")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        elseif num == exit_option then
            print("\nYou step back from the cursed market. The cultists nod in silence.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        else
            -- Purchase item
            local item = selected_items[num]
            local hp_cost = item.hp_cost
            
            if player.hp > hp_cost then
                print("\n🩸 Purchase " .. item.name .. " for " .. hp_cost .. " HP?")
                print("1. Yes")
                print("2. No")
                io.write("\nYour choice: ")
                local confirm = io.read()
                
                if confirm == "1" then
                    player.hp = player.hp - hp_cost
                    
                    -- Handle special items
                    if item.shop_expansion then
                        player.blood_shop_expansions = (player.blood_shop_expansions or 0) + 1
                        print("\n🔻 The blood market expands! +1 item will be available next time.")
                    else
                        player:add_item(item)
                    end
                    
                    print("\n🩸 Purchase completed! HP: " .. player.hp .. "/" .. player.max_hp)
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                end
            else
                print("\n❌ You don't have enough HP! (Need " .. hp_cost .. " HP)")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Random event: Blood Shrine
local function shrine_event()
    clear_console()
    
    -- Check if cultists should appear (first time completing a ritual)
    if player.blood_ritual_completed_before and not player.cultists_encountered then
        print("🩸 You approach the ancient blood shrine, but you are not alone...")
        print("🔻 Three figures in bloody robes surround the shrine.")
        print("Their faces are hidden, but you sense their eyes upon you.")
        print("Almost as if they were waiting for you.")
        print("")
        print("They gesture toward the shrine, and a collection of dark items.")
        print("🔻 They silently gesture to some dark items.")
        print("")
        print("")
        player.cultists_encountered = true
        
        print("1. Browse the Blood Market")
        print("2. Make an offering to the shrine") 
        print("3. Leave this cursed place")
        io.write("\nYour choice: ")
        local choice = io.read()
        
        if choice == "1" then
            blood_shop()
            return
        elseif choice == "2" then
            -- Fall through to normal shrine logic
        else
            print("\nYou back away slowly. The cultists watch you go in silence.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        end
    end
    
    print("🩸 You come across an ancient shrine demanding blood in exchange for power.")
    print("It whispers: \27[131mOffer your blood, or turn away.\27[0m")

    -- Show blood market option if cultists have been encountered
    if player.cultists_encountered then
        print("\n🔻 The cultists' shadows seem to linger here...")
    end

    -- Check if player has paladin powers - they'll get burned but still have a choice
    local has_paladin_powers = player.paladin_light_ability or player.reflect_ability or player.clarity_ability
    if has_paladin_powers then
        print("\n⚠️  The shrine senses the holy light within you and radiates hostility.")
        print("You can feel it will burn you if you approach, but the choice remains yours.")
    end

    print("\n1. Accept the sacrifice (-20 HP" .. (has_paladin_powers and " + burn damage" or "") .. ")")
    if player.cultists_encountered then
        print("2. Browse the Blood Market")
        print("3. Deny and move on")
    else
        print("2. Deny and move on")
    end
    
    io.write("\nYour choice: ")
    local choice = io.read()
    
    if choice == "1" then
        -- Apply burn damage if player has paladin powers
        if has_paladin_powers then
            print("\nAs you reach out, the shrine burns your hand! It rejects the holy light you carry.")
            local burn_dmg = 10
            if player.hp <= burn_dmg then
                player.hp = 0
            else
                player.hp = player.hp - burn_dmg
            end
            print("🔥 You take " .. burn_dmg .. " damage from the scorching touch!")
        end

        -- Ensure the player has enough HP to survive the sacrifice (considering burn damage)
        if player.hp > 20 then
            -- First time sacrifice: mark the player and grant a random blood ability
            if not player.bloodmark then
                player.hp = player.hp - 20
                player.bloodmark = true
                -- Randomly grant one of the three blood abilities on first visit
                local available = { "strike", "drain", "boil" }
                local pick = available[math.random(#available)]

                if pick == "strike" then
                    player.blood_strike_ability = true
                    player.abilities_enabled.blood_strike = true
                    player:unlock_ability("Blood Strike")
                    print("\nYou offer your blood. (HP -20)")
                    print(
                    "The shrine etches you with the mark of blood.\nYou have gained the Blood Strike ability!\nSacrifice 20 HP and 8 stamina for a powerful strike.")
                elseif pick == "drain" then
                    player.blood_drain_ability = true
                    player.abilities_enabled.blood_drain = true
                    player:unlock_ability("Blood Drain")
                    print("\nYou offer your blood. (HP -20)")
                    print(
                    "The shrine etches you with the mark of blood.\nYou have gained the Blood Drain ability!\nSteal 10 HP from your foe at the cost of 5 stamina.")
                elseif pick == "boil" then
                    player.blood_boil_ability = true
                    player.abilities_enabled.blood_boil = true
                    player:unlock_ability("Blood Boil")
                    print("\nYou offer your blood. (HP -20)")
                    print(
                    "The shrine etches you with the mark of blood.\nYou have gained the Blood Boil ability!\nLose 20 HP to restore 10 stamina and gain +5 Power/Accuracy for your next two attacks.")
                end
            else
                -- If already blood marked, grant an additional blood ability without cost
                local available = {}
                if not player.blood_drain_ability then table.insert(available, "drain") end
                if not player.blood_boil_ability then table.insert(available, "boil") end
                if not player.blood_strike_ability then table.insert(available, "strike") end
                if #available > 0 then
                    local pick = available[math.random(#available)]
                    if pick == "drain" then
                        player.blood_drain_ability = true
                        player.abilities_enabled.blood_drain = true
                        player:unlock_ability("Blood Drain")
                        print(
                        "\nThe shrine gifts you the Blood Drain ability!\nSteal 10 HP from your foe at the cost of 5 stamina.")
                    elseif pick == "boil" then
                        player.blood_boil_ability = true
                        player.abilities_enabled.blood_boil = true
                        player:unlock_ability("Blood Boil")
                        print(
                        "\nThe shrine gifts you the Blood Boil ability!\nLose 20 HP to restore 10 stamina and gain +5 Power/Accuracy for your next two attacks.")
                    elseif pick == "strike" then
                        player.blood_strike_ability = true
                        player.abilities_enabled.blood_strike = true
                        player:unlock_ability("Blood Strike")
                        print(
                        "\nThe shrine reawakens your Blood Strike ability!\nSacrifice 20 HP and 8 stamina for a devastating blow.")
                    end
                else
                    print("\nThe shrine offers no further gifts. You already wield all of its power.")
                end
            end
        else
            print("\n❌ You are too weak to make a sacrifice. The shrine's power fades.")
        end
    elseif choice == "2" and player.cultists_encountered then
        blood_shop()
        return
    else
        print("\nYou refuse the shrine's request and continue on your way.")
    end
    io.write("\nPress Enter to continue...")
    local _ = io.read()
end

-- Random event: a wandering paladin offers holy powers.  If the
-- player is blood marked the paladin refuses to aid them.  If
-- accepted, a random paladin ability is granted.  Accepting the
-- blessing also unlocks the Radiance skill tree (handled via
-- player.paladinmark).
local function paladin_event()
    clear_console()
    print("🔰  A wandering paladin crosses your path, his armor gleaming.")
    -- Blood marked characters cannot receive a paladin blessing
    if player.bloodmark then
        print("✨ He notices the blood mark in your flesh.")
        print("\"Begone, foul one!\" he scoffs, backing away.")
        
        -- But if you have Blood Ritual, you can still use it on him
        if (player.skills["Blood Oath"] or 0) >= 5 and player.abilities_enabled.blood_ritual then
            print("\nYou sense an opportunity...")
            print("\n1. 🩸 Blood Ritual")
            print("2. Leave him be and move on")
            
            io.write("\nYour choice: ")
            local choice = io.read()
            
            if choice == "1" then
                clear_console()
                print("🩸 You begin the dark ritual, channeling blood energy...")
                print("The paladin's eyes widen as he realizes what you're doing.")
                print("\"You dare attempt your vile ritual on me?!\" he shouts, drawing his weapon.")
                
                -- Mark paladins as permanently hostile
                player.paladins_hostile = true
                
                -- Set flag for immediate paladin combat
                player.immediate_paladin_combat = true
                
                print("\n⚔️  The paladin prepares to attack!")
                
                io.write("\nPress Enter to enter combat...")
                local _ = io.read()
                
                -- Force transition to arena where the paladin will be the first enemy
                player.inshop = false
                return
            else
                print("\nYou turn and leave the hostile paladin behind.")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
                return
            end
        else
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        end
    end
    print("✨ He offers to bestow upon you the power of light.")
    print("\n1. Accept the blessing")
    print("2. Decline and move on")
    
    io.write("\nYour choice: ")
    local choice = io.read()
    
    if choice == "1" then
        player.paladinmark = true
        -- Determine which paladin ability to grant.  Only grant
        -- abilities the player does not already possess.
        local options = {}
        if not player.paladin_light_ability then table.insert(options, "light") end
        if not player.reflect_ability then table.insert(options, "reflect") end
        if not player.clarity_ability then table.insert(options, "clarity") end
        if #options > 0 then
            local pick = options[math.random(#options)]
            if pick == "light" then
                player.paladin_light_ability = true
                player.abilities_enabled.paladin_light = true
                player:unlock_ability("Paladin's Light")
                print("\nThe paladin lays his hand on you, channeling radiant energy.")
                print(
                "✨ You learned Paladin's Light!  -10 stamina, blinds your enemy for this and the next turn (they deal no damage) and heals you for 10 HP.")
            elseif pick == "reflect" then
                player.reflect_ability = true
                player.abilities_enabled.reflect = true
                player:unlock_ability("Reflect")
                print("\nThe paladin bestows upon you the power of reflection.")
                print(
                "🔰 You learned Reflect!  -8 stamina, negate 80% of incoming damage next turn. Half of negated damage is reflected back, half heals you.")
            elseif pick == "clarity" then
                player.clarity_ability = true
                player.abilities_enabled.clarity = true
                player:unlock_ability("Clarity")
                print(
                "\n🧘 The paladin grants you Clarity!  -8 stamina, a precise attack with +5 Power, +5 Accuracy and +5 Defense.")
            end
        else
            print("\nYou already possess all of the paladin's gifts.")
        end
    else
        print("\nYou politely decline and continue on your journey.")
    end
    io.write("\nPress Enter to continue...")
    local _ = io.read()
end

-- Define a small pool of merchant‑only items.  These items provide
-- persistent upgrades to the shop and potion mechanics.  They are
-- flagged as unsellable and will not appear in the normal item
-- pools.
merchant_item_pool = {
    {
        name = "Extra Stock",
        rarity = "uncommon",
        price = 60,
        extra_stock_bonus = 1,
        is_merchant_item = true,
        description = "+1 additional item appears in the regular shop"
    },
    {
        name = "Healing Potion Upgrade",
        rarity = "uncommon",
        price = 65,
        health_potion_upgrade_bonus = 1,
        is_merchant_item = true,
        description = "Restore more HP per stack"
    },
    {
        name = "Stamina Potion Upgrade",
        rarity = "uncommon",
        price = 65,
        stamina_potion_upgrade_bonus = 1,
        is_merchant_item = true,
        description = "Restore more stamina per stack"
    },
    {
        name = "Evasion Potion Upgrade",
        rarity = "uncommon",
        price = 65,
        evasion_potion_upgrade_bonus = 1,
        is_merchant_item = true,
        description = "Using evasion potions grants temporary shop discounts for that visit"
    },
    {
        name = "Merchant's Bangle",
        rarity = "rare",
        price = 120,
        merchant_bangle_bonus = 1,
        is_merchant_item = true,
        description = "Reduces the cost of items and increases their sell prices"
    },
    {
        name = "Inventory Upgrade",
        rarity = "rare",
        price = 100,
        inventory_upgrade = 1,
        is_merchant_item = true,
        description = "Increases inventory capacity by 1 slot"
    }
}

-- Define a pool of scholar‑only items.  Each entry is a tome
-- corresponding to a specific skill set.  Purchasing a tome from
-- the scholar permanently increases the maximum investment cap for
-- that skill from 5 to 10 points.  The price of each tome is
-- balanced to reflect the power of the skill tree.
scholar_item_pool = {}
for _, skill in ipairs(skill_definitions) do
    -- Skip Blood Oath tome - it's moved to the blood shop
    if skill.name ~= "Blood Oath" then
        -- Build a descriptive name.  Use "Tome" rather than "Book" for
        -- flavour and to avoid confusion with potions.  Skills like
        -- "Blood Oath" and "Radiance" will therefore have tomes named
        -- "Blood Oath Tome" and "Radiance Tome".
        local item_name = skill.name .. " Tome"
        -- Set a base price.  More potent skill trees could be priced
        -- higher if desired.  Here all tomes cost 80 coins by default.
        local price = 80
        table.insert(scholar_item_pool, {
            name = item_name,
            rarity = "uncommon",
            price = price,
            skill_book_for = skill.name,
            description = "Unlocks +5 additional points in the " .. skill.name .. " skill set"
        })
    end
end

-- Define blood cult shop items - costs HP instead of coins
-- Uses the new "cursed" rarity (🔻) for blood cult items
blood_shop_pool = {
    {
        name = "Blood Oath Tome",
        rarity = "cursed",
        hp_cost = 40,
        skill_book_for = "Blood Oath",
        description = "Unlocks +5 additional points in the Blood Oath skill set"
    },
    {
        name = "Cultist Robes",
        rarity = "cursed",
        hp_cost = 60,
        max_hp_bonus = -10,
        sneak_bonus = 20,
        blood_ability_cost_reduction = 3, -- Reduces stamina costs for all blood abilities by 3
        description = "-10 Max HP, +20 Sneak, -3 Stamina cost for all Blood abilities"
    },
    {
        name = "Blood Shop Expansion",
        rarity = "cursed", 
        hp_cost = 30,
        shop_expansion = true,
        description = "Adds 1 more item to the Blood Shop selection"
    }
}

-- Random event: Scholar encounter
--
-- The player occasionally meets a wandering scholar.  The first
-- meeting requires a one‑time fee to unlock the Focus skill set and
-- gain access to the scholar's tomes.  After paying the fee the
-- scholar will offer tomes for each skill set which increase the
-- maximum investible points for that skill from 5 to 10.
local function scholar_event()
    clear_console()
    print("📜 A wise scholar approaches, his robes covered in arcane sigils.")
    -- If the scholar has not yet been paid, demand a one‑time fee to
    -- unlock Focus and access his tomes
    if not player.scholar_paid then
        local fee = 50 -- cost for the initial lesson unlocking Focus
        -- Use single quotes to easily embed double quotes in the message
        print('\n"Greetings, adventurer," he says. "There is much I can teach you."')
        print('"For a one‑time fee of ' .. fee .. ' coins I will share the secrets of Focus and open my library to you."')
        print("\n1. Pay the fee")
        print("2. Decline and move on")
        io.write("\nYour choice: ")
        local choice = io.read()
        if choice == "1" then
            if player.coins >= fee then
                player.coins = player.coins - fee
                player.scholar_paid = true
                player.focus_unlocked = true
                clear_console()
                print("📖 You hand over the coins.  The scholar teaches you the art of Focus.")
                print("The Focus skill set is now available to you!")
                print("\nHe reveals a collection of tomes, each promising deeper mastery over your skills.")
                io.write("\nPress Enter to browse the tomes...")
                local _ = io.read()
            else
                print("\n❌ You do not have enough coins to pay the scholar.")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
                return
            end
        else
            print("\nYou decline and continue on your journey.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        end
    end
    -- At this point the scholar has been paid; open the tome shop
    while true do
        -- Build a list of tomes that the player has not yet purchased
        local offerings = {}
        for _, item in ipairs(scholar_item_pool) do
            -- Offer only tomes for which the player has not already unlocked the skill cap
            if not player.skill_books[item.skill_book_for] then
                table.insert(offerings, item)
            end
        end
        clear_console()
        -- Display player status similar to other shops
        print("You (Level " .. player.level .. ") HP ❤️ : " .. player.hp .. "/" .. player.max_hp ..
        " | Stamina ⚡ : " .. player.stamina .. "/" .. player.max_stamina)
        print("  ❤️   " .. player.health_potions .. " | ⚡  " .. player.stamina_potions .. " | 🧪  " .. player.evasion_potions ..
        " | 💰  " .. player.coins .. " | 🌟  " .. player.skill_points)
        print("")
        if #offerings == 0 then
            print("📚 The scholar smiles, \"You have learned all I can teach.\"")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        end
        print("📚 The scholar's tomes:")
        print("")
        for i, item in ipairs(offerings) do
            local sym = get_rarity_symbol(item.rarity)
            local cost = item.price
            print(i .. ". " .. sym .. " " .. item.name .. " - " .. item.description .. "  - \27[33m" .. cost .. " coins\27[0m")
        end
        print("")
        print((#offerings + 1) .. ". Leave the scholar")
        io.write("\nYour choice: ")
        local choice = io.read()
        local num = tonumber(choice)
        if not num or num < 1 or num > #offerings + 1 then
            print("\n❌ Invalid choice. Try again.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
        elseif num == #offerings + 1 then
            print("\nYou thank the scholar and continue on your journey.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        else
            local item = offerings[num]
            local cost = item.price
            if player.coins >= cost then
                player.coins = player.coins - cost
                -- Use player:add_item to apply the skill book effect.  This will
                -- call player:unlock_skill_book and not take inventory space.
                player:add_item(item)
                print("\nYou purchase " .. item.name .. " for \27[33m" .. cost .. " coins\27[0m!")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            else
                print("\n❌ You do not have enough coins for that tome.")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Random event: a traveling merchant.  He sells a selection of
-- special upgrades unavailable elsewhere.  The player may buy
-- exactly one item per encounter from his unique pool.  Prices are
-- subject to reduction based on any Merchant's Bangle owned.
local function merchant_event()
    clear_console()
    print("🛍️  You encounter a traveling merchant with a bag of unique goods.")
    print("He beckons you over and displays his wares.")
    print("")
    print("1. 🛍️  Browse his wares")
    print("2. 🚶 Continue on your journey")
    print("")
    io.write("Your choice: ")
    local choice = io.read()

    if choice == "2" then
        print("You decline and continue on your journey.")
        io.write("\nPress Enter to continue...")
        local _ = io.read()
        return
    elseif choice ~= "1" then
        print("The merchant shrugs and packs up his wares as you walk past.")
        io.write("\nPress Enter to continue...")
        local _ = io.read()
        return
    end

    -- Generate a small list of offerings from the merchant's pool.  We
    -- show up to 3 items each time, selecting randomly without
    -- replacement.  If less than 3 remain, we show all.
    local offerings = {}
    -- Clone the merchant pool to avoid modifying the original
    local pool_copy = {}
    for _, itm in ipairs(merchant_item_pool) do table.insert(pool_copy, itm) end
    local count = math.min(3, #pool_copy)
    for i = 1, count do
        local idx = math.random(#pool_copy)
        table.insert(offerings, pool_copy[idx])
        table.remove(pool_copy, idx)
    end
    while true do
        clear_console()
        -- Display status like the shop
        print("You (Level " ..
        player.level ..
        ") HP ❤️ : " ..
        player.hp .. "/" .. player.max_hp .. " | Stamina ⚡ : " .. player.stamina .. "/" .. player.max_stamina)
        print("  ❤️   " ..
        player.health_potions ..
        " | ⚡  " ..
        player.stamina_potions ..
        " | 🧪  " .. player.evasion_potions .. " | 💰  " .. player.coins .. " | 🌟  " .. player.skill_points)
        print("")
        print("🛍️  I got what you need!")
        print("")
        print("Items for sale:")

        for i, item in ipairs(offerings) do
            local sym = get_rarity_symbol(item.rarity)
            -- Apply Merchant's Bangle and temporary Evasion Potion bonus discounts to price.  Each point
            -- reduces cost by 2% of the base price.  The cost cannot
            -- drop below 50% of original price.
            local evasion_discount = player.evasion_bonus_active and player.evasion_potion_upgrades or 0
            local total_discount_bonus = player.merchant_bangle + evasion_discount
            local discount = 1 - (0.02 * total_discount_bonus)
            if discount < 0.5 then discount = 0.5 end
            local cost = math.max(1, math.floor(item.price * discount + 0.5))
            print(i ..
            ". " .. sym .. " " .. item.name .. " (" .. item.description .. ")  - \27[33m" .. cost .. " coins\27[0m")
        end
        print("")
        print((#offerings + 1) .. ". Leave the merchant")
        print("")
        print("")
        io.write("Your choice: ")
        local choice = io.read()
        local num = tonumber(choice)
        if not num or num < 1 or num > #offerings + 1 then
            print("❌ Invalid choice. Try again.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
        elseif num == #offerings + 1 then
            print("You thank the merchant and continue on your journey.")
            io.write("\nPress Enter to continue...")
            local _ = io.read()
            return
        else
            local item = offerings[num]
            -- Calculate discounted cost including temporary evasion bonus
            local evasion_discount = player.evasion_bonus_active and player.evasion_potion_upgrades or 0
            local total_discount_bonus = player.merchant_bangle + evasion_discount
            local discount = 1 - (0.02 * total_discount_bonus)
            if discount < 0.5 then discount = 0.5 end
            local cost = math.max(1, math.floor(item.price * discount + 0.5))
            if player.coins >= cost then
                player.coins = player.coins - cost
                -- Merchant items have no resale value; don't set item.price
                local purchased = {
                    name = item.name,
                    rarity = item.rarity,
                    -- Mark as merchant so it cannot be sold and to apply
                    -- special effects.
                    is_merchant_item = true,
                    extra_stock_bonus = item.extra_stock_bonus,
                    health_potion_upgrade_bonus = item.health_potion_upgrade_bonus,
                    stamina_potion_upgrade_bonus = item.stamina_potion_upgrade_bonus,
                    evasion_potion_upgrade_bonus = item.evasion_potion_upgrade_bonus,
                    merchant_bangle_bonus = item.merchant_bangle_bonus,
                    inventory_upgrade = item.inventory_upgrade, -- Add missing inventory upgrade field
                    description = item.description
                }
                player:add_item(purchased)
                print("You purchase " .. purchased.name .. " for \27[33m" .. cost .. " coins\27[0m!")
                -- Remove the purchased item from offerings so it can't be bought again
                table.remove(offerings, num)
                io.write("\nPress Enter to continue...")
                local _ = io.read()
                -- Check if all items have been sold
                if #offerings == 0 then
                    print("🛍️ The merchant packs up his remaining wares.")
                    print("'That's all I have for now. Pleasure doing business with you!'")
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                    return
                end
            else
                print("❌ You do not have enough coins for that item.")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Random Event Pool.
local function trigger_random_event()
    -- 15% chance that an event occurs instead of a monster encounter
    local event_roll = math.random(1, 100)
    if event_roll <= 50 then
        -- Determine which event to trigger.  Weighted distribution:
        -- 30% chest, 30% shrine, 20% paladin, 10% merchant, 10% scholar.
        local which = math.random(1, 100)
        if which <= 30 then
            chest_event()
        elseif which <= 60 then
            shrine_event()
        elseif which <= 80 then
            paladin_event()
        elseif which <= 90 then
            merchant_event()
        else
            scholar_event()
        end
        return true
    end
    return false
end
-- Shop function
function run_shop()
    -- Clear the screen and generate a fresh set of shop items once per shop visit
    clear_for_transition()

    -- Equip any temporary items found during arena runs
    player:equip_temp_items()

    local shop_items = generate_shop_items()

    -- Helper to open the inventory screen from the shop.  The
    -- function loops until the user chooses to return to the shop or
    -- exits via the skill menu.  It returns a string: "shop" when
    -- returning directly to the shop, or "inventory" to re‑open
    -- inventory (if the user returned from the skills menu).
    local function open_inventory_screen()
        while true do
            clear_console()
            
            print("💼 +" ..
            player.inventory_upgrades ..
            " | Your Inventory: (" .. #player.inventory .. "/" .. player.max_inventory .. ")")
            print("❤️   " ..
            player.health_potions ..
            " | ⚡  " ..
            player.stamina_potions ..
            " | 🧪  " .. player.evasion_potions .. " | 💰  " .. player.coins .. " | 🌟 " .. player.skill_points)
            print("")

            if #player.inventory == 0 then
                print("  Empty")
            else
                for i, item in ipairs(player.inventory) do
                    local sym = get_rarity_symbol(item.rarity)
                    local sell_info = ""
                    if item.price then
                        local sell_price = math.floor(item.price / 2)
                        sell_info = " \27[33m" .. sell_price .. " coins\27[0m"
                    else
                        sell_info = " \27[90munsellable\27[0m"
                    end
                    print("  " .. i .. ". " .. sym .. " " .. item.name .. " - " .. item.description .. sell_info)
                end
            end

            -- Show temporary items if any
            if #player.temp_items > 0 then
                print("")
                print("📦 Items found in arena (will be equipped here):")
                for i, item in ipairs(player.temp_items) do
                    local sym = get_rarity_symbol(item.rarity)
                    print("  " .. sym .. " " .. item.name .. " - " .. item.description)
                end
            end

            print("")
            print("")
            -- Display current stats summary
            print("💪  " .. player.power .. "  | 🛡️  " .. player.defense .. " | 🎯  " .. player.accuracy)
            print("💨  " .. player.dodge .. "  | 🕵️  " .. player.sneak .. " | 🍀  " .. player.luck)
            print("❤️  " .. player.max_hp .. " | ⚡  " .. player.max_stamina .. " | ♻️  " .. player.stamina_regen)
            print("")
            print("0. 🏪 Return to Shop")
            print("Enter to see your Skill Sets 📚")
            print("")
            io.write("Choose an item number to sell it to the shop: ")

            local inv_choice = io.read()
            if inv_choice == nil then inv_choice = "" end

            -- Check for restart input
            if check_restart_input(inv_choice) then
                return "restart"
            end

            if inv_choice == "" then
                -- Open skills menu; determine where to go based on return value
                local result = open_skills_menu()
                if result == "shop" then
                    return "shop"
                elseif result == "restart" then
                    return "restart"
                elseif result == "inventory" then
                    -- Continue inventory loop
                end
            elseif inv_choice == "0" then
                return "shop"
            else
                local sell_num = tonumber(inv_choice)
                if sell_num and sell_num >= 1 and sell_num <= #player.inventory then
                    local success, value_or_msg, item_name = player:sell_item(sell_num)
                    clear_console()
                    if success then
                        print("💸 Sold " ..
                        item_name ..
                        " for \27[33m" ..
                        value_or_msg .. " coins\27[0m! Total coins: \27[33m" .. player.coins .. "\27[0m")
                    else
                        print("❌ " .. value_or_msg)
                    end
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                else
                    if #player.inventory > 0 then
                        clear_console()
                        print("❌ Invalid choice! Please choose a valid item number.")
                        io.write("\nPress Enter to continue...")
                        local _ = io.read()
                    end
                end
            end
        end
    end

    -- Stay in the shop until the player chooses to return to the arena or runs out of HP
    while player.hp > 0 and player.inshop == true do
        clear_console()
        -- Show flee damage message once
        if pending_flee_message ~= nil then
            print(pending_flee_message)
            print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
            pending_flee_message = nil
        end
        -- Display status and shop header in new format
        print("You (Level " ..
        player.level ..
        ") HP ❤️ : " ..
        player.hp .. "/" .. player.max_hp .. " | Stamina ⚡ : " .. player.stamina .. "/" .. player.max_stamina)
        print("  ❤️   " ..
        player.health_potions ..
        " | ⚡  " ..
        player.stamina_potions ..
        " | 🧪  " .. player.evasion_potions .. " | 💰  " .. player.coins .. " | 🌟  " .. player.skill_points)
        print("")
        print("🏪 Welcome to the shop!")
        print("")
        print("Items for sale:")
        -- Consumable potions for sale (all potions cost 20 coins; stamina potion restores 10)
        local health_heal = 20 + (player.health_potion_upgrades * 5)
        local stamina_restore = 10 + (player.stamina_potion_upgrades * 3)
        local health_name = "Health Potion" .. string.rep("+", player.health_potion_upgrades)
        local stamina_name = "Stamina Potion" .. string.rep("+", player.stamina_potion_upgrades)
        local evasion_name = "Evasion Potion" .. string.rep("+", player.evasion_potion_upgrades)

        print("1. ❤️  " .. health_name .. " (+" .. health_heal .. " HP) - \27[33m20 coins\27[0m")
        print("2. ⚡ " .. stamina_name .. " (+" .. stamina_restore .. " Stamina) - \27[33m20 coins\27[0m")
        print("3. 🧪 " .. evasion_name .. " (safe escape)  - \27[33m20 coins\27[0m")

        -- Display the randomly generated equipment items
        for i, item in ipairs(shop_items) do
            local rarity_symbol = get_rarity_symbol(item.rarity)
            -- Apply discounts from Merchant's Bangle and temporary evasion bonus (if active)
            local evasion_discount = player.evasion_bonus_active and player.evasion_potion_upgrades or 0
            local total_discount_bonus = player.merchant_bangle + evasion_discount
            local discount = 1 - (0.02 * total_discount_bonus)
            if discount < 0.5 then discount = 0.5 end
            local cost = math.max(1, math.floor(item.price * discount + 0.5))
            print((i + 3) ..
            ". " ..
            rarity_symbol .. " " .. item.name .. " (" .. item.description .. ")  - \27[33m" .. cost .. " coins\27[0m")
        end

        print("")
        print("0. ⚔️  Return to Arena")
        print("Enter to View Your Inventory 💼")
        print("")
        print("")
        io.write("Your choice: ")
        local choice = io.read()
        if choice == nil then choice = "" end

        -- Check for restart input
        if check_restart_input(choice) then
            return
        end

        if choice == "0" then
            -- Return to the arena
            if not player:check_inventory_limit() then
                clear_console()
                print("❌ Your inventory is too full! (Max: " .. player.max_inventory .. " items)")
                print("You have " ..
                #player.inventory .. " items. Please sell or drop some items before entering the arena.")
                print("")
                io.write("Press Enter to continue...")
                local _ = io.read()
            else
                player.inshop = false
                -- Clear temporary evasion potion bonus when leaving shop
                if player.evasion_bonus_active then
                    player.evasion_bonus_active = false
                    print("💫 Evasion potion shop bonus has worn off.")
                    io.write("\nPress Enter to continue...")
                    local _ = io.read()
                end
                clear_console()
                print("⚔️ Returning to the arena!")
                clear_for_transition()
            end
        elseif choice == "" then
            -- Open the inventory screen.  If the inventory screen signals
            -- to return to the shop, continue; otherwise reprint the
            -- inventory again.
            local result = open_inventory_screen()
            if result == "restart" then
                return
            end
            -- When returning from the skills menu directly to shop,
            -- simply loop back to display the shop again.
            -- Otherwise, continue with the next iteration (inventory re‑opened)
        else
            local choice_num = tonumber(choice)
            if choice_num and choice_num >= 1 and choice_num <= 3 + #shop_items then
                clear_console()
                if choice_num == 1 then
                    -- Purchase a health potion
                    if player.coins >= 20 then
                        player.coins = player.coins - 20
                        player.health_potions = player.health_potions + 1
                        print("✅ Bought Health Potion! Total: " .. player.health_potions)
                    else
                        print("❌ Not enough coins! Need \27[33m20 coins\27[0m.")
                    end
                elseif choice_num == 2 then
                    -- Purchase a stamina potion
                    if player.coins >= 20 then
                        player.coins = player.coins - 20
                        player.stamina_potions = player.stamina_potions + 1
                        print("✅ Bought Stamina Potion! Total: " .. player.stamina_potions)
                    else
                        print("❌ Not enough coins! Need \27[33m20 coins\27[0m.")
                    end
                elseif choice_num == 3 then
                    -- Purchase an evasion potion
                    if player.coins >= 20 then
                        player.coins = player.coins - 20
                        player.evasion_potions = player.evasion_potions + 1
                        print("✅ Bought Evasion Potion! Total: " .. player.evasion_potions)
                    else
                        print("❌ Not enough coins! Need \27[33m20 coins\27[0m.")
                    end
                else
                    -- Purchase equipment item
                    local item_index = choice_num - 3
                    local item = shop_items[item_index]
                    -- Apply discounts from Merchant's Bangle and temporary evasion bonus (if active)
                    local evasion_discount = player.evasion_bonus_active and player.evasion_potion_upgrades or 0
                    local total_discount_bonus = player.merchant_bangle + evasion_discount
                    local discount = 1 - (0.02 * total_discount_bonus)
                    if discount < 0.5 then discount = 0.5 end
                    local cost = math.max(1, math.floor(item.price * discount + 0.5))
                    if player.coins >= cost then
                        player.coins = player.coins - cost
                        player:add_item(item)
                    else
                        print("❌ Not enough coins! Need \27[33m" .. cost .. " coins\27[0m.")
                    end
                end
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            else
                clear_console()
                print("❌ Invalid choice!")
                io.write("\nPress Enter to continue...")
                local _ = io.read()
            end
        end
    end
end

-- Arena function
function run_arena()
    -- Track the last action result across the entire arena run.  This
    -- string holds the most recent combat narrative and is used when
    -- the player dies to show what happened immediately before defeat.
    local final_action_log = ""
    local first_encounter = true
    while player.hp > 0 and player.inshop == false do
        if first_encounter then
            clear_for_transition()
            first_encounter = false
        end
        
        local monster
        local undetected = false
        local pickpocket_used = false
        
        -- Check for immediate paladin combat from Blood Ritual
        if player.immediate_paladin_combat then
            player.immediate_paladin_combat = false
            monster = generate_paladin_enemy()
            
            -- Activate Blood Ritual at the start of paladin combat
            clear_console()
            print("🩸 The Blood Ritual begins as combat starts!")
            
            -- Apply Blood Ritual immediately
            player.blood_ritual_active = true
            player.blood_ritual_stacks = 0
            
            -- First stack damage and stats
            player.hp = player.hp - 20
            player.blood_ritual_stacks = 1
            
            -- Apply first stack bonuses
            player.power = player.power + 1
            player.accuracy = player.accuracy + 1
            player.sneak = player.sneak + 5
            player.defense = player.defense - 1
            
            -- Track bonuses for cleanup
            player.blood_ritual_power_gained = 1
            player.blood_ritual_accuracy_gained = 1
            player.blood_ritual_sneak_gained = 5
            player.blood_ritual_defense_lost = 1
            
            print("🩸 Blood Ritual drains 20 HP!")
            
            -- Guaranteed initial hit for 1 damage to draw blood
            monster.hp = monster.hp - 1
            print("🩸 You cut the " .. monster.name .. " for 1 damage and draw their blood.")
            
            -- Apply bleeding to enemy for 2 turns
            monster.poison_turns = 2
            monster.poison_damage = 5
            print("🔻 The " .. monster.name .. " is now bleeding!")
            
            print("")
            print("⚔️ Combat begins!")
            io.write("Press Enter to continue...")
            local _ = io.read()
        else
            -- Check for a random event before generating a monster.  If an
            -- event occurs, skip spawning a monster and continue to the next
            -- loop iteration.  Events like chests and shrines add variety
            -- to the arena encounters.
            if trigger_random_event() then
                clear_for_transition()
            else
                monster = generate_monster()

                -- Before announcing the monster, determine if the player has
                -- entered unnoticed.  This sets up the stealth state for
                -- this encounter.  If undetected, we print a notice so the
                -- player knows stealth actions are available.
                if roll_entry_sneak() then
                    undetected = true
                end
                -- Reset pickpocket flag each encounter so the player can
                -- attempt to steal once per fight.
                pickpocket_used = false
            end
        end
        
        if monster then

            if monster.is_boss then
                print("\n🔥 BOSS APPEARS! 🔥")
                print("A " ..
                    monster.name ..
                    " (Level " .. monster.level .. ") emerges! (" .. monster.hp .. "/" .. monster.max_hp .. " HP)")
                print("Special: " .. monster.special_ability)
            else
                print("\nA Level " ..
                    monster.level ..
                    " " .. monster.name .. " appears! (" .. monster.hp .. "/" .. monster.max_hp .. " HP)")
                print("Special: " .. monster.special_ability)
            end

            -- Display stealth message after monster info so it won't be cleared
            if undetected then
                print("🕵️  You've entered the room undetected!")
            end

            print("")

            local last_action_result = ""
            while monster.hp > 0 and player.hp > 0 and player.inshop == false do
                -- Clear console first
                clear_console()

                -- Apply ongoing poison damage to the monster at the start of
                -- the player's turn.  Poison ignores defense and deals a
                -- fixed amount each turn until the effect ends.
                if monster.poison_turns and monster.poison_turns > 0 then
                    local poison_dmg = monster.poison_damage or 0
                    if poison_dmg > 0 then
                        monster.hp = monster.hp - poison_dmg
                        if monster.hp < 0 then monster.hp = 0 end
                        if last_action_result == "" then
                            last_action_result = "☠️  Poison deals " ..
                            poison_dmg .. " damage to " .. monster.name .. "!\n"
                        else
                            last_action_result = last_action_result ..
                            "☠️  Poison deals " .. poison_dmg .. " damage to " .. monster.name .. "!\n"
                        end
                    end
                    monster.poison_turns = monster.poison_turns - 1
                end

                -- Player info
                print("You (Level " ..
                player.level ..
                ") HP: ❤️  " ..
                player.hp .. "/" .. player.max_hp .. " | Stamina: ⚡ " .. player.stamina .. "/" .. player.max_stamina)

                -- Show ongoing status effects for the player
                local status_msgs = {}
                if undetected then
                    table.insert(status_msgs, "🕵️  Undetected")
                end
                if player.blinded_turns and player.blinded_turns > 0 then
                    table.insert(status_msgs, "😵 Blinded (" .. player.blinded_turns .. " turns)")
                end
                if player.blood_boiling_turns and player.blood_boiling_turns > 0 then
                    table.insert(status_msgs, "🔥 Blood Boiling (" .. player.blood_boiling_turns .. " turns)")
                end
                if player.blood_ritual_active then
                    table.insert(status_msgs, "🩸 Blood Ritual (" .. player.blood_ritual_stacks .. " stacks)")
                end
                if player.holy_ritual_active then
                    table.insert(status_msgs, "✨ Holy Ritual (" .. player.holy_ritual_stacks .. " stacks)")
                end
                if player.shield_wall_turns and player.shield_wall_turns > 0 then
                    table.insert(status_msgs, "🛡️ Shield Wall (" .. player.shield_wall_turns .. " turns)")
                end
                if player.holy_aura_turns and player.holy_aura_turns > 0 then
                    table.insert(status_msgs, "✨ Holy Aura (" .. player.holy_aura_turns .. " turns)")
                end
                if player.reflect_active then
                    table.insert(status_msgs, "🔰 Reflect ready")
                end
                if #status_msgs > 0 then
                    print("  " .. table.concat(status_msgs, " | "))
                end

                print("\27[38;5;240m════════════════════════════════════════════════\27[0m")

                -- Show last action result after player info
                if last_action_result ~= "" then
                    print(last_action_result:gsub("\n$", ""))
                    print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
                    last_action_result = ""
                end

                -- Display monster info
                print(monster.name ..
                " (Lvl " ..
                monster.level ..
                ") ❤️  " ..
                monster.hp .. "/" .. monster.max_hp .. " | ⚡: " .. monster.stamina .. "/" .. monster.max_stamina)

                -- Show monster status effects
                local monster_status = {}
                if monster.blinded_turns and monster.blinded_turns > 0 then
                    table.insert(monster_status, "😵 Blinded (" .. monster.blinded_turns .. " turns)")
                end
                if monster.stunned_turns and monster.stunned_turns > 0 then
                    table.insert(monster_status, "💫 Stunned (" .. monster.stunned_turns .. " turns)")
                end
                if monster.poison_turns and monster.poison_turns > 0 then
                    table.insert(monster_status, "☠️ Poisoned (" .. monster.poison_turns .. " turns)")
                end
                if monster.thick_hide_turns and monster.thick_hide_turns > 0 then
                    table.insert(monster_status, "🛡️ Thick Hide (" .. monster.thick_hide_turns .. " turns)")
                end
                if monster.reflect_active then
                    table.insert(monster_status, "� Reflect ready")
                end
                if monster.clarity_turns and monster.clarity_turns > 0 then
                    table.insert(monster_status, "🧘 Clarity (" .. monster.clarity_turns .. " turns)")
                end
                if #monster_status > 0 then
                    print("  " .. table.concat(monster_status, " | "))
                end

                print("")
                print("\27[38;5;240mActions:\27[0m")
                print("\27[38;5;240m════════════════════════════════════════════════\27[0m")

                -- Build a dynamic list of available actions based on the
                -- player's current inventory and unlocked abilities.  Only
                -- actions the player can perform appear in the menu.
                local actions = {}
                local option_idx = 1

                -- Check if attack is enabled
                if player.abilities_enabled.attack then
                    actions[option_idx] = "attack"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🗡️  Attack")
                    option_idx = option_idx + 1
                end

                -- Check if strong attack is enabled
                if player.abilities_enabled.strong_attack then
                    actions[option_idx] = "strong_attack"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 💪 Strong Attack -3⚡")
                    option_idx = option_idx + 1
                end

                -- Blood Strike action unlocked from the shrine event
                if player.blood_strike_ability and player.abilities_enabled.blood_strike then
                    actions[option_idx] = "blood_strike"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🩸 Blood Strike -20❤️, -8⚡")
                    option_idx = option_idx + 1
                end

                if player.heal_ability and player.abilities_enabled.heal then
                    actions[option_idx] = "heal"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " ✨ Heal -5⚡")
                    option_idx = option_idx + 1
                end

                if player.health_potions > 0 then
                    actions[option_idx] = "health_potion"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " ❤️  Use Health Potion")
                    option_idx = option_idx + 1
                end

                if player.stamina_potions > 0 then
                    actions[option_idx] = "stamina_potion"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " ⚡ Use Stamina Potion")
                    option_idx = option_idx + 1
                end

                if player.evasion_potions > 0 then
                    actions[option_idx] = "evasion_potion"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🧪 Use Evasion Potion")
                    option_idx = option_idx + 1
                end

                -- Group blood and paladin abilities together so they appear
                -- adjacent in the action list.  These powers draw from
                -- recent shrine or paladin encounters and are unlocked
                -- individually.  Grouping them here makes them easier
                -- to find during combat.
                -- Blood Strike (shrine ability)
                -- NOTE: Blood Strike is printed earlier with basic attacks if unlocked.
                -- Additional blood abilities unlocked by the blood shrine
                if player.blood_drain_ability and player.abilities_enabled.blood_drain then
                    actions[option_idx] = "blood_drain"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🩸 Blood Drain -5⚡")
                    option_idx = option_idx + 1
                end
                if player.blood_boil_ability and player.abilities_enabled.blood_boil then
                    actions[option_idx] = "blood_boil"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🔥 Blood Boil -20❤️, +10⚡")
                    option_idx = option_idx + 1
                end
                -- Paladin powers from Radiance line
                if player.paladin_light_ability and player.abilities_enabled.paladin_light then
                    actions[option_idx] = "paladin_light"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " ✨ Paladin's Light -10⚡")
                    option_idx = option_idx + 1
                end
                if player.reflect_ability and player.abilities_enabled.reflect then
                    actions[option_idx] = "reflect"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🔰 Reflect -8⚡")
                    option_idx = option_idx + 1
                end
                if player.clarity_ability and player.abilities_enabled.clarity then
                    actions[option_idx] = "clarity"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🧘 Clarity -8⚡")
                    option_idx = option_idx + 1
                end

                -- When undetected, provide stealth actions with a detection
                -- chance that depends on enemy level and the player's sneak stat.
                if undetected then
                    -- calculate base detection chance: each monster level adds
                    -- 10% to detection difficulty and every 2 points of sneak
                    -- subtracts 1%.  This value has a minimum of 5%.
                    local det_chance = (monster.level * 10) - math.floor(player.sneak / 2)
                    if det_chance < 5 then det_chance = 5 end
                    -- Sneak past: bypass the current encounter
                    actions[option_idx] = "sneak_past"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🚪 Sneak Past (" .. det_chance .. "% detect)")
                    option_idx = option_idx + 1
                    -- Pickpocket: steal coins or items once per fight
                    if not pickpocket_used then
                        actions[option_idx] = "pickpocket"
                        print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 💼 Pickpocket (" .. det_chance .. "% detect)")
                        option_idx = option_idx + 1
                    end
                    -- Backstab: stealth attack with temporary stat boosts
                    actions[option_idx] = "backstab"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🔪 Backstab -5⚡ (" .. det_chance .. "% detect)")
                    option_idx = option_idx + 1
                end

                -- Flee to the shop.  We handle fleeing separately from
                -- numbered actions so that pressing Enter will always
                -- execute a flee regardless of how many abilities are
                -- available.  If you are still hidden, there is a chance
                -- to avoid damage while escaping based on your sneak
                -- stat.  Once detected, fleeing always results in taking a
                -- hit from the monster.  We will print the flee message
                -- after all other actions.

                -- Append blood, paladin, and skill abilities to the action
                -- list.  These appear after the standard combat options.
                -- Skill set abilities unlock when at least 5 points are invested
                -- Fighter: Shield Bash stuns the enemy for one turn and deals normal damage
                if (player.skills["Fighter"] or 0) >= 5 and player.abilities_enabled.shield_bash then
                    actions[option_idx] = "shield_bash"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🛡️  Shield Bash -6⚡")
                    option_idx = option_idx + 1
                end
                -- Elusive: Shadow Step re-enters stealth
                if (player.skills["Elusive"] or 0) >= 5 and player.abilities_enabled.shadow_step then
                    actions[option_idx] = "shadow_step"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 👣 Shadow Step -6⚡")
                    option_idx = option_idx + 1
                end
                -- Focus: Meditate heals and restores stamina
                if (player.skills["Focus"] or 0) >= 5 and player.abilities_enabled.meditate then
                    actions[option_idx] = "meditate"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🧠 Meditate -5⚡")
                    option_idx = option_idx + 1
                end
                -- Fortitude: Second Wind provides a burst of HP and stamina
                if (player.skills["Fortitude"] or 0) >= 5 and player.abilities_enabled.second_wind then
                    actions[option_idx] = "second_wind"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🌬️ Second Wind -5⚡")
                    option_idx = option_idx + 1
                end
                -- Assassin: Poisoned Strike applies a poison effect
                if (player.skills["Assassin"] or 0) >= 5 and player.abilities_enabled.poisoned_strike then
                    actions[option_idx] = "poisoned_strike"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🗡️  Poisoned Strike -6⚡")
                    option_idx = option_idx + 1
                end
                -- Tank: Shield Wall halves incoming damage for two turns
                if (player.skills["Tank"] or 0) >= 5 and player.abilities_enabled.shield_wall then
                    actions[option_idx] = "shield_wall"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🧱 Shield Wall -6⚡")
                    option_idx = option_idx + 1
                end
                -- Lucky: Jackpot provides bonus coins and extra drop chance
                if (player.skills["Lucky"] or 0) >= 5 and player.abilities_enabled.jackpot then
                    actions[option_idx] = "jackpot"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🍀 Jackpot -10⚡")
                    option_idx = option_idx + 1
                end
                -- Berserk: Frenzy trades HP for a double strike
                if (player.skills["Berserk"] or 0) >= 5 and player.abilities_enabled.frenzy then
                    actions[option_idx] = "frenzy"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🔥 Frenzy -8⚡, -10❤️")
                    option_idx = option_idx + 1
                end
                -- Blood Oath: Blood Ritual sacrifices HP for permanent boosts this fight
                if player.bloodmark and (player.skills["Blood Oath"] or 0) >= 5 and player.abilities_enabled.blood_ritual then
                    actions[option_idx] = "blood_ritual"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " 🩸 Blood Ritual -15⚡, -20❤️")
                    option_idx = option_idx + 1
                end
                -- Radiance: Holy Ritual sacrifices stamina for permanent defensive boosts
                if player.paladinmark and (player.skills["Radiance"] or 0) >= 5 and player.abilities_enabled.holy_ritual then
                    actions[option_idx] = "holy_ritual"
                    print("\27[38;5;240m" .. option_idx .. ".\27[0m" .. " ✨ Holy Ritual -15⚡")
                    option_idx = option_idx + 1
                end

                -- After listing all numbered actions, provide the flee option as 0
                print("")
                if undetected then
                    local flee_det = (monster.level * 10) - math.floor(player.sneak / 2)
                    if flee_det < 5 then flee_det = 5 end
                    print("\27[38;5;240m0.\27[0m" .. " 🏪 Flee to the shop (" .. flee_det .. "% detect)")
                else
                    print("\27[38;5;240m0.\27[0m" .. " 🏪 Flee to the shop (take damage)")
                end
                print("Press Enter to view Abilities 🧬")

                io.write("\nYour Action: ")
                local choice_input = io.read()
                local selected
                if choice_input == nil or choice_input == "" then
                    -- Empty input (pressing Enter) corresponds to viewing abilities
                    show_arena_abilities()
                    -- Set selected to a special value to skip this turn
                    selected = "view_abilities"
                elseif choice_input == "0" then
                    -- 0 input corresponds to fleeing
                    selected = "flee"
                else
                    local choice_num = tonumber(choice_input)
                    if choice_num then
                        selected = actions[choice_num]
                    end
                end
                -- Store action results instead of printing immediately
                local action_text = ""
                -- Flag used to skip stamina regeneration on strong attacks
                local skip_regen = false

                -- Any non‑stealth action instantly breaks stealth.  Only
                -- the dedicated stealth options (sneak past, pickpocket,
                -- backstab) and the Elusive skill ability "Shadow Step" are
                -- allowed while hidden without alerting the monster.  Once
                -- you perform a normal attack, use an ability or drink a
                -- potion, you are considered detected and cannot flee
                -- without taking a hit.  This ensures the detection roll
                -- for fleeing is only available before combat has begun.
                if undetected then
                    if selected ~= "sneak_past" and selected ~= "pickpocket" and selected ~= "backstab" and selected ~= "shadow_step" then
                        undetected = false
                    end
                end

                if selected == "attack" then
                    local hit, dmg, miss_reason = player:attack(monster)
                    if hit then
                        action_text = action_text ..
                        "🗡️  You attacked " .. monster.name .. " and dealt " .. dmg .. " damage!\n"
                        
                        -- Handle monster reflect
                        if monster.reflect_active and dmg > 0 then
                            local reflected = math.floor(dmg * (monster.reflect_percent / 100))
                            player.hp = player.hp - reflected
                            monster.reflect_active = false
                            monster.reflect_percent = 0
                            action_text = action_text .. "🔰 " .. monster.name .. " reflects " .. reflected .. " damage back at you!\n"
                        end
                    else
                        if miss_reason then
                            action_text = action_text .. miss_reason .. "\n"
                        else
                            action_text = action_text .. "💨 " .. monster.name .. " dodged your attack!\n"
                        end
                    end
                elseif selected == "strong_attack" then
                    if player.stamina >= 3 then
                        player.stamina = player.stamina - 3
                        skip_regen = true
                        local original_power = player.power
                        player.power = player.power + 5
                        local hit, dmg = player:strong_attack(monster)
                        player.power = original_power
                        if hit then
                            action_text = action_text ..
                            "💪 You used Strong Attack on " .. monster.name .. " and dealt " .. dmg .. " damage!\n"
                        else
                            action_text = action_text .. "💨 " .. monster.name .. " dodged your strong attack!\n"
                        end
                    else
                        action_text = action_text .. "❌ Not enough stamina for Strong Attack!\n"
                    end
                elseif selected == "blood_strike" then
                    -- Blood Strike: sacrifice 20 HP and 8 stamina to gain +8 power and accuracy for one attack and +50 dodge for one round
                    if player.blood_strike_ability then
                        local stamina_cost = math.max(1, 8 - (player.blood_ability_cost_reduction or 0))
                        if player.stamina >= stamina_cost and player.hp > 20 then
                            player.stamina = player.stamina - stamina_cost
                            skip_regen = true
                            player.hp = player.hp - 20
                            local original_power = player.power
                            local original_accuracy = player.accuracy
                            player.power = player.power + 8
                            player.accuracy = player.accuracy + 8
                            player.temp_dodge_bonus = (player.temp_dodge_bonus or 0) + 50
                            local hit, dmg = player:attack(monster)
                            player.power = original_power
                            player.accuracy = original_accuracy
                            if hit then
                                action_text = action_text ..
                                "🩸 You unleashed a Blood Strike on " ..
                                monster.name .. " and dealt " .. dmg .. " damage!\n"
                            else
                                action_text = action_text .. "💨 " .. monster.name .. " dodged your Blood Strike!\n"
                            end
                        else
                            if player.stamina < stamina_cost then
                                action_text = action_text .. "❌ Not enough stamina for Blood Strike!\n"
                            else
                                action_text = action_text .. "❌ Not enough HP to sacrifice for Blood Strike!\n"
                            end
                        end
                    end
                elseif selected == "heal" then
                    -- Heal ability uses stamina to restore HP
                    if player.stamina >= 5 then
                        player.stamina = player.stamina - 5
                        skip_regen = true
                        local heal_amt = 20
                        player.hp = math.min(player.max_hp, player.hp + heal_amt)
                        action_text = action_text .. "✨ You focus and heal yourself for " .. heal_amt .. " HP!\n"
                    else
                        action_text = action_text .. "❌ Not enough stamina to heal!\n"
                    end
                elseif selected == "health_potion" then
                    -- Use health potion; base healing is 20 plus 5 per
                    -- health potion upgrade.  This allows the Healing
                    -- Potion Upgrade item to meaningfully increase the
                    -- value of each potion.
                    player.health_potions = player.health_potions - 1
                    local heal_amt = 20 + player.health_potion_upgrades * 5
                    player.hp = math.min(player.max_hp, player.hp + heal_amt)
                    action_text = action_text .. "❤️  You used a Health Potion and restored " .. heal_amt .. " HP!\n"
                elseif selected == "stamina_potion" then
                    -- Use stamina potion; restores 10 stamina base, plus
                    -- bonuses from any potion upgrades (each upgrade adds
                    -- an additional 3 points).  This makes stamina potions
                    -- more meaningful during longer fights.
                    player.stamina_potions = player.stamina_potions - 1
                    local restore_amt = 10 + player.stamina_potion_upgrades * 3
                    player.stamina = math.min(player.max_stamina, player.stamina + restore_amt)
                    action_text = action_text ..
                    "⚡ You used a Stamina Potion and restored " .. restore_amt .. " stamina!\n"
                elseif selected == "evasion_potion" then
                    -- Use evasion potion if available
                    if player:use_evasion_potion() then
                        clear_for_transition()
                        break
                    end
                elseif selected == "sneak_past" then
                    -- Attempt to sneak past the current encounter.  Roll
                    -- detection; if caught the monster gets a free hit and
                    -- stealth ends.  Otherwise the player skips to the next
                    -- room without any rewards.
                    local det = (monster.level * 10) - math.floor(player.sneak / 2)
                    if det < 5 then det = 5 end
                    local roll = math.random(1, 100)
                    if roll <= det then
                        -- Detected: suffer a free attack (reduced damage) and lose stealth
                        local dmg = math.random(1, math.floor(monster.power / 2))
                        player.hp = player.hp - dmg
                        undetected = false
                        action_text = action_text ..
                        "⚠️  You were detected while sneaking past! The " ..
                        monster.name .. " strikes you for " .. dmg .. " damage!\n"
                    else
                        -- Sneak successful: move on to the next encounter
                        clear_console()
                        print("🕵️  You sneak past the " .. monster.name .. " undetected and move on.")
                        io.write("\nPress Enter to continue...")
                        local _ = io.read()
                        clear_for_transition()
                        -- Skip the remainder of this fight entirely
                        player.inshop = false -- Stay in arena mode
                        break             -- Exit the combat loop to continue arena loop
                    end
                elseif selected == "pickpocket" then
                    -- Attempt to steal coins or an item.  Once per fight.
                    local det = (monster.level * 10) - math.floor(player.sneak / 2)
                    if det < 5 then det = 5 end
                    local roll = math.random(1, 100)
                    -- Determine loot: 30% chance for item, otherwise coins.  Luck influences amounts and item rarity.
                    local loot_text = ""
                    local stole_item = false
                    if math.random(1, 100) <= 30 then
                        -- Roll item rarity influenced by luck
                        local rarity_roll = math.random(1, 100)
                        local rare_threshold = 5 + player.luck
                        if rare_threshold > 25 then rare_threshold = 25 end
                        local uncommon_threshold = 30 + player.luck * 2
                        if uncommon_threshold > 80 then uncommon_threshold = 80 end
                        local rarity
                        if rarity_roll <= rare_threshold then
                            rarity = "rare"
                        elseif rarity_roll <= rare_threshold + uncommon_threshold then
                            rarity = "uncommon"
                        else
                            rarity = "common"
                        end
                        local pool = {}
                        for _, itm in ipairs(item_pool) do
                            if itm.rarity == rarity then
                                table.insert(pool, itm)
                            end
                        end
                        if #pool > 0 then
                            local drop = pool[math.random(#pool)]
                            player:add_temp_item(drop)
                            loot_text = "📦 You pickpocketed " ..
                            get_rarity_symbol(drop.rarity) .. " " .. drop.name .. "!\n"
                            stole_item = true
                        end
                    end
                    if not stole_item then
                        -- Steal coins: base amount scales with monster level and luck
                        local base_coins = math.random(3, math.max(3, math.floor(monster.coinDrop / 2)))
                        local luck_bonus = math.random(0, player.luck)
                        local coins = base_coins + luck_bonus
                        player.coins = player.coins + coins
                        loot_text = "💰 You pickpocketed \27[33m" ..
                        coins .. " coins\27[0m! Total: \27[33m" .. player.coins .. "\27[0m\n"
                    end
                    pickpocket_used = true
                    -- Check for detection after stealing
                    if roll <= det then
                        -- Detected while pickpocketing
                        undetected = false
                        -- Free attack as penalty for being caught
                        local dmg = math.random(1, math.floor(monster.power / 2))
                        player.hp = player.hp - dmg
                        loot_text = loot_text ..
                        "⚠️  You were detected! The " ..
                        monster.name ..
                        " strikes you for " .. dmg .. " damage! (rolled " .. roll .. " vs " .. det .. "%)\n"
                    else
                        -- Successfully remained undetected
                        loot_text = loot_text ..
                        "🕵️  You remain undetected. (rolled " .. roll .. " vs " .. det .. "%)\n"
                    end
                    action_text = action_text .. loot_text
                elseif selected == "backstab" then
                    -- Backstab: a stealth attack that sacrifices stamina to
                    -- temporarily boost stats.  Detection chance applies and
                    -- if caught the monster gets a free hit and you do not
                    -- benefit from the guaranteed dodge.  Only when undetected
                    -- at the moment of striking will you dodge the next
                    -- attack.
                    if player.stamina >= 5 then
                        -- Compute detection chance
                        local det = (monster.level * 10) - math.floor(player.sneak / 2)
                        if det < 5 then det = 5 end
                        local roll = math.random(1, 100)
                        -- Spend stamina and apply temporary bonuses
                        player.stamina = player.stamina - 5
                        skip_regen = true
                        local orig_power = player.power
                        local orig_acc = player.accuracy
                        player.power = player.power + 3
                        player.accuracy = player.accuracy + 5
                        -- Determine if you remain undetected for the attack
                        local detected = (roll <= det)
                        -- Only grant guaranteed dodge if you were not detected
                        if not detected then
                            player.guaranteed_dodge_next = true
                        end
                        -- Perform the attack
                        local hit, dmg = player:attack(monster)
                        -- Revert stats
                        player.power = orig_power
                        player.accuracy = orig_acc
                        if hit then
                            action_text = action_text ..
                            "🔪  You perform a Backstab on " .. monster.name .. " and deal " .. dmg .. " damage!\n"
                        else
                            action_text = action_text .. "💨 " .. monster.name .. " dodged your Backstab!\n"
                        end
                        -- End stealth state regardless of detection outcome
                        undetected = false
                        if detected then
                            -- If detected, the monster gets a free hit that
                            -- deals partial damage.  There is no guaranteed
                            -- dodge in this case.
                            local dmg2 = math.random(1, math.floor(monster.power / 2))
                            player.hp = player.hp - dmg2
                            action_text = action_text ..
                            "⚠️  You were detected! The " .. monster.name .. " strikes you for " .. dmg2 .. " damage!\n"
                        end
                    else
                        action_text = action_text .. "❌ Not enough stamina for Backstab!\n"
                        -- Failed backstab attempt reveals the player
                        undetected = false
                    end
                elseif selected == "flee" then
                    -- Check if Blood Ritual is active - prevents safe fleeing
                    if player.blood_ritual_active then
                        player.hp = 0  -- Blood ritual demands sacrifice - player dies
                        action_text = action_text .. 
                            "💀 You cannot escape the Blood Ritual! The blood debt demands your life!\n" ..
                            "The ritual consumes you as you attempt to flee!\n"
                        break
                    end
                    
                    -- Flee to the shop.  There is a chance to avoid damage
                    -- based on your sneak versus the monster's level.  If
                    -- undetected, fleeing will never trigger a free hit.
                    -- Set shop flag immediately.  Whether damage is taken
                    -- depends on if the player was still undetected at
                    -- the time of fleeing.  Once detected, fleeing
                    -- guarantees a hit from the monster.
                    player.inshop = true
                    local flee_message
                    if undetected then
                        local det = (monster.level * 10) - math.floor(player.sneak / 2)
                        if det < 5 then det = 5 end
                        local flee_roll = math.random(1, 100)
                        if flee_roll <= det then
                            -- Detected while fleeing: take damage
                            local flee_dmg = math.random(1, math.floor(monster.power / 2))
                            player.hp = player.hp - flee_dmg
                            flee_message = "You retreat back to the shop!\nYou take " ..
                            flee_dmg .. " damage while fleeing!"
                        else
                            -- Successfully sneaked away: no damage
                            flee_message = "You retreat back to the shop unnoticed and take no damage!"
                        end
                    else
                        -- Already detected: you always take damage on escape
                        local flee_dmg = math.random(1, math.floor(monster.power / 2))
                        player.hp = player.hp - flee_dmg
                        flee_message = "You retreat back to the shop!\nYou take " .. flee_dmg .. " damage while fleeing!"
                    end
                    pending_flee_message = flee_message
                    last_action_result = flee_message
                    clear_for_transition()
                    break
                elseif selected == "blood_drain" then
                    -- Blood Drain: cost 5 stamina; steals 10 HP from the enemy
                    if player.blood_drain_ability then
                        local stamina_cost = math.max(1, 5 - (player.blood_ability_cost_reduction or 0))
                        if player.stamina >= stamina_cost then
                            player.stamina = player.stamina - stamina_cost
                            skip_regen = true
                            -- Drain 10 HP from monster and heal player
                            local drain_amt = 10
                            if monster.hp < drain_amt then drain_amt = monster.hp end
                            monster.hp = monster.hp - drain_amt
                            player.hp = math.min(player.max_hp, player.hp + drain_amt)
                            action_text = action_text ..
                            "🩸 You siphon " .. drain_amt .. " HP from " .. monster.name .. " and restore yourself!\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Blood Drain!\n"
                        end
                    end
                elseif selected == "blood_boil" then
                    -- Blood Boil: lose 20 HP, gain 10 stamina, and +5 power/accuracy for next 2 attacks
                    if player.blood_boil_ability then
                        if player.hp > 20 then
                            player.hp = player.hp - 20
                            player.stamina = math.min(player.max_stamina, player.stamina + 10)
                            player.blood_boiling_turns = (player.blood_boiling_turns or 0) + 2
                            action_text = action_text ..
                            "🔥 Your blood begins to boil! You gain +5 Power/Accuracy for your next two attacks and restore 10 stamina. (HP -20)\n"
                        else
                            action_text = action_text .. "❌ Not enough HP to fuel Blood Boil!\n"
                        end
                    end
                elseif selected == "paladin_light" then
                    -- Paladin's Light: cost 10 stamina; blinds the monster and heals 10 HP
                    if player.paladin_light_ability then
                        if player.stamina >= 10 then
                            player.stamina = player.stamina - 10
                            skip_regen = true
                            -- Heal player
                            player.hp = math.min(player.max_hp, player.hp + 10)
                            -- Blind monster for 2 turns (don't stack)
                            monster.blinded_turns = 2
                            action_text = action_text ..
                            "✨ You invoke Paladin's Light! " ..
                            monster.name .. " is blinded for 2 turns and you heal 10 HP.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina to invoke Paladin's Light!\n"
                        end
                    end
                elseif selected == "reflect" then
                    -- Reflect: cost 8 stamina; negate a portion of next attack and reflect
                    if player.reflect_ability then
                        if player.stamina >= 8 then
                            player.stamina = player.stamina - 8
                            skip_regen = true
                            -- Determine reflect percentage based on defense, capped at 50%
                            local percent = math.floor(player.defense / 2)
                            if percent > 50 then percent = 50 end
                            if percent < 10 then percent = 10 end
                            player.reflect_active = true
                            player.reflect_percent = percent
                            action_text = action_text ..
                            "🔁 You prepare to reflect the next attack! " ..
                            percent .. "% of incoming damage will be negated, half reflected and half healed.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina to use Reflect!\n"
                        end
                    end
                elseif selected == "clarity" then
                    -- Clarity: cost 8 stamina; attack with +5 power/accuracy/defense
                    if player.clarity_ability then
                        if player.stamina >= 8 then
                            player.stamina = player.stamina - 8
                            skip_regen = true
                            -- Temporarily boost power, accuracy and defense
                            local orig_power = player.power
                            local orig_acc = player.accuracy
                            local orig_def = player.defense
                            player.power = player.power + 5
                            player.accuracy = player.accuracy + 5
                            player.defense = player.defense + 5
                            local hit, dmg = player:attack(monster)
                            -- Revert stats
                            player.power = orig_power
                            player.accuracy = orig_acc
                            player.defense = orig_def
                            if hit then
                                action_text = action_text .. "🧘 You strike with clarity, dealing " .. dmg .. " damage!\n"
                            else
                                action_text = action_text .. "💨 " .. monster.name .. " dodged your Clarity strike!\n"
                            end
                        else
                            action_text = action_text .. "❌ Not enough stamina for Clarity!\n"
                        end
                    end
                elseif selected == "shield_bash" then
                    -- Fighter ability: Shield Bash stuns enemy for one turn and deals normal damage
                    if (player.skills["Fighter"] or 0) >= 5 then
                        if player.stamina >= 6 then
                            player.stamina = player.stamina - 6
                            skip_regen = true
                            local hit, dmg = player:attack(monster)
                            if hit then
                                action_text = action_text ..
                                "🛡️  You bash " .. monster.name .. " with your shield, dealing " .. dmg .. " damage!\n"
                            else
                                action_text = action_text .. "💨 " .. monster.name .. " dodged your Shield Bash!\n"
                            end
                            monster.stunned_turns = (monster.stunned_turns or 0) + 1
                            action_text = action_text ..
                            "💫 " .. monster.name .. " is stunned and cannot attack next turn!\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Shield Bash!\n"
                        end
                    end
                elseif selected == "shadow_step" then
                    -- Elusive ability: Shadow Step allows re-entering stealth mid-fight
                    if (player.skills["Elusive"] or 0) >= 5 then
                        if player.stamina >= 6 then
                            player.stamina = player.stamina - 6
                            skip_regen = true
                            undetected = true
                            pickpocket_used = false
                            action_text = action_text .. "👣 You melt back into the shadows, gaining stealth again.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Shadow Step!\n"
                        end
                    end
                elseif selected == "meditate" then
                    -- Focus ability: Meditate heals HP and restores stamina
                    if (player.skills["Focus"] or 0) >= 5 then
                        if player.stamina >= 5 then
                            player.stamina = player.stamina - 5
                            skip_regen = true
                            local heal_hp = 15
                            local heal_stam = 5
                            player.hp = math.min(player.max_hp, player.hp + heal_hp)
                            player.stamina = math.min(player.max_stamina, player.stamina + heal_stam)
                            action_text = action_text ..
                            "🧠 You meditate, restoring " .. heal_hp .. " HP and " .. heal_stam .. " stamina.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina to meditate!\n"
                        end
                    end
                elseif selected == "second_wind" then
                    -- Fortitude ability: Second Wind grants a surge of HP and stamina
                    if (player.skills["Fortitude"] or 0) >= 5 then
                        if player.stamina >= 5 then
                            player.stamina = player.stamina - 5
                            skip_regen = true
                            local heal_hp = 30
                            local heal_stam = 5
                            player.hp = math.min(player.max_hp, player.hp + heal_hp)
                            player.stamina = math.min(player.max_stamina, player.stamina + heal_stam)
                            action_text = action_text ..
                            "🌬️ You catch a Second Wind, restoring " ..
                            heal_hp .. " HP and " .. heal_stam .. " stamina.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Second Wind!\n"
                        end
                    end
                elseif selected == "poisoned_strike" then
                    -- Assassin ability: Poisoned Strike deals normal damage and poisons enemy
                    if (player.skills["Assassin"] or 0) >= 5 then
                        if player.stamina >= 6 then
                            player.stamina = player.stamina - 6
                            skip_regen = true
                            local hit, dmg = player:attack(monster)
                            if hit then
                                action_text = action_text ..
                                "☠️  You deliver a poisoned strike to " .. monster.name .. " for " .. dmg .. " damage!\n"
                            else
                                action_text = action_text .. "💨 " .. monster.name .. " dodged your Poisoned Strike!\n"
                            end
                            -- Apply poison for 3 turns, 5 damage per turn
                            monster.poison_turns = 3
                            monster.poison_damage = 5
                            action_text = action_text .. "☠️  " .. monster.name .. " is poisoned!\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Poisoned Strike!\n"
                        end
                    end
                elseif selected == "shield_wall" then
                    -- Tank ability: Shield Wall halves incoming damage for two turns
                    if (player.skills["Tank"] or 0) >= 5 then
                        if player.stamina >= 6 then
                            player.stamina = player.stamina - 6
                            skip_regen = true
                            player.shield_wall_turns = (player.shield_wall_turns or 0) + 2
                            action_text = action_text ..
                            "🧱 You raise your shield and brace yourself! Damage taken reduced by 50% for 2 turns.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Shield Wall!\n"
                        end
                    end
                elseif selected == "jackpot" then
                    -- Lucky ability: Jackpot provides bonus coins and extra drop chance
                    if (player.skills["Lucky"] or 0) >= 5 then
                        if player.stamina >= 10 then
                            player.stamina = player.stamina - 10
                            skip_regen = true
                            player.jackpot_active = true
                            action_text = action_text ..
                            "🍀 You feel luck on your side! The next monster kill will grant bonus coins and an extra chance for an item drop!\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina for Jackpot!\n"
                        end
                    end
                elseif selected == "frenzy" then
                    -- Berserk ability: Frenzy attacks twice at the cost of HP and stamina
                    if (player.skills["Berserk"] or 0) >= 5 then
                        if player.stamina >= 8 and player.hp > 10 then
                            player.stamina = player.stamina - 8
                            skip_regen = true
                            player.hp = player.hp - 10
                            -- Perform two attacks
                            for i = 1, 2 do
                                local hit, dmg = player:attack(monster)
                                if hit then
                                    action_text = action_text ..
                                    "🔥 Frenzy strike " .. i .. " deals " .. dmg .. " damage!\n"
                                else
                                    action_text = action_text .. "💨 Frenzy strike " .. i .. " missed!\n"
                                end
                                if monster.hp <= 0 then break end
                            end
                        else
                            action_text = action_text ..
                            "❌ Not enough resources for Frenzy! Requires 8 stamina and 10 HP.\n"
                        end
                    end
                elseif selected == "blood_ritual" then
                    -- New Blood Ritual: Demands a sacrifice - enemy or player death
                    if player.bloodmark and (player.skills["Blood Oath"] or 0) >= 5 then
                        if not player.blood_ritual_active then
                            local stamina_cost = math.max(1, 15 - (player.blood_ability_cost_reduction or 0))
                            if player.stamina >= stamina_cost then
                                player.stamina = player.stamina - stamina_cost
                                skip_regen = true
                                player.stamina_regen = player.stamina_regen + 1
                                player.blood_ritual_active = true
                                player.blood_ritual_stacks = 0
                                
                                -- Guaranteed initial hit for 1 damage to draw blood
                                monster.hp = monster.hp - 1
                                if monster.hp < 0 then monster.hp = 0 end
                                
                                -- Apply bleeding to enemy for 2 turns
                                monster.poison_turns = 2
                                monster.poison_damage = 5
                                
                                action_text = action_text ..
                                "🩸 You begin the Blood Ritual! You cut the enemy for 1 damage and draw their blood.\n" ..
                                "🔻 A SACRIFICE IS DEMANDED.\n"
                            else
                                action_text = action_text .. "❌ Not enough stamina to begin a Blood Ritual!\n"
                            end
                        else
                            action_text = action_text .. "❌ A Blood Ritual is already in progress!\n"
                        end
                    end
                elseif selected == "holy_ritual" then
                    -- Radiance ability: Holy Ritual builds defensive stacks like Blood Ritual but with different effects
                    if player.paladinmark and (player.skills["Radiance"] or 0) >= 5 then
                        if not player.holy_ritual_active then
                            if player.stamina >= 15 then
                                player.stamina = player.stamina - 15
                                skip_regen = true
                                player.stamina_regen = player.stamina_regen - 1 -- Reduce stamina regen during Holy Ritual
                                player.holy_ritual_active = true
                                player.holy_ritual_stacks = 1 -- Start with first stack
                                
                                -- Apply holy stat bonuses
                                player.holy_ritual_defense_bonus = 1
                                player.holy_ritual_maxhp_bonus = 5
                                player.holy_ritual_power_bonus = -1
                                player.holy_ritual_sneak_bonus = -5
                                
                                player.defense = player.defense + 1
                                player.max_hp = player.max_hp + 5
                                player.hp = player.hp + 5
                                player.power = player.power - 1
                                player.sneak = player.sneak - 5
                                
                                -- Blind monster for 3 turns
                                monster.blinded_turns = 3
                                
                                action_text = action_text ..
                                "✨ You begin the Holy Ritual! The room fills with radiant light.\n" ..
                                "🌟 " .. monster.name .. " is blinded for 3 turns!\n" ..
                                "✨ You gain +1 Defense, +5 Max HP, -1 Power, -5 Sneak\n"
                            else
                                action_text = action_text .. "❌ Not enough stamina to begin a Holy Ritual!\n"
                            end
                        else
                            action_text = action_text .. "❌ A Holy Ritual is already in progress!\n"
                        end
                    end
                    if player.paladinmark and (player.skills["Radiance"] or 0) >= 5 then
                        if player.stamina >= 8 then
                            player.stamina = player.stamina - 8
                            skip_regen = true
                            local heal = 15
                            player.hp = math.min(player.max_hp, player.hp + heal)
                            player.holy_aura_turns = (player.holy_aura_turns or 0) + 2
                            action_text = action_text ..
                            "🌟 You invoke a Holy Aura! Damage taken reduced by 30% for 2 turns and you heal " ..
                            heal .. " HP.\n"
                        else
                            action_text = action_text .. "❌ Not enough stamina to invoke Holy Aura!\n"
                        end
                    end
                elseif selected == "view_abilities" then
                    -- Special action to view abilities during combat
                    -- This doesn't take a turn, set flag to skip turn processing
                    selected = "skip_turn"
                else
                    action_text = action_text .. "❌ Invalid choice. You lose your turn!\n"
                end

                -- Skip all turn processing if viewing abilities
                if selected ~= "skip_turn" then
                    -- Regenerate stamina at the end of the player's turn unless
                    -- they performed a strong attack (cost remains 3 stamina)
                    if not skip_regen then
                        player.stamina = math.min(player.max_stamina, player.stamina + player.stamina_regen)
                    end

                    -- Blood Ritual per-turn effects - must happen after each player action
                    if player.blood_ritual_active then
                        -- Take 20 damage from the ritual
                        player.hp = player.hp - 20
                        player.blood_ritual_stacks = player.blood_ritual_stacks + 1
                        
                        -- Apply permanent stat bonuses for this stack
                        player.power = player.power + 1
                        player.accuracy = player.accuracy + 1
                        player.sneak = player.sneak + 5
                        player.defense = player.defense - 1
                        
                        -- Track bonuses for cleanup
                        player.blood_ritual_power_bonus = player.blood_ritual_power_bonus + 1
                        player.blood_ritual_sneak_bonus = player.blood_ritual_sneak_bonus + 5
                        player.blood_ritual_defense_bonus = player.blood_ritual_defense_bonus - 1
                        
                        action_text = action_text .. 
                            "🩸 Blood Ritual drains 20 HP! Stack " .. player.blood_ritual_stacks .. 
                            ": +1 Power/Accuracy, +5 Sneak, -1 Defense\n"
                        
                        -- Check if player dies from ritual damage
                        if player.hp <= 0 then
                            action_text = action_text .. 
                                "💀 The Blood Ritual has consumed you! The blood debt demanded your life!\n"
                        end
                    end
                    
                    -- Holy Ritual per-turn effects
                    if player.holy_ritual_active and monster.hp <= 0 then
                        -- When monster dies, gain a Holy Ritual stack
                        player.holy_ritual_stacks = player.holy_ritual_stacks + 1
                        
                        -- Apply permanent stat bonuses for this stack
                        player.defense = player.defense + 1
                        player.max_hp = player.max_hp + 5
                        player.hp = player.hp + 5
                        player.power = player.power - 1
                        player.sneak = player.sneak - 5
                        
                        -- Track bonuses for cleanup
                        player.holy_ritual_defense_bonus = player.holy_ritual_defense_bonus + 1
                        player.holy_ritual_maxhp_bonus = player.holy_ritual_maxhp_bonus + 5
                        player.holy_ritual_power_bonus = player.holy_ritual_power_bonus - 1
                        player.holy_ritual_sneak_bonus = player.holy_ritual_sneak_bonus - 5
                        
                        action_text = action_text .. 
                            "✨ Holy Ritual grants a new stack! Stack " .. player.holy_ritual_stacks .. 
                            ": +1 Defense, +5 Max HP, -1 Power, -5 Sneak\n"
                    end

                    -- Monster special behaviors and attacks
                    if monster.hp > 0 and not player.inshop then
                        -- Worm: Activate thick hide if below 50% health and hasn't used it yet
                        if monster.name == "Worm" and not monster.thick_hide_used and monster.hp <= monster.max_hp / 2 and monster.stamina >= 5 then
                            monster.stamina = monster.stamina - 5
                            monster.thick_hide_turns = 3
                            monster.thick_hide_used = true
                            action_text = action_text ..
                            "🐛 " ..
                            monster.name .. " activates Thick Hide! (+10 Defense, -5 Power/Accuracy for 3 turns)\n"
                        end

                        -- Slime regeneration (now costs stamina)
                        if monster.name == "Slime" and math.random(1, 4) == 1 and monster.stamina >= 3 and monster.hp < monster.max_hp then
                            monster.stamina = monster.stamina - 3
                            local regen = math.min(5, monster.max_hp - monster.hp)
                            monster.hp = monster.hp + regen
                            action_text = action_text .. "💚 " .. monster.name .. " regenerated " .. regen .. " HP!\n"
                        end

                        -- Hostile Paladin abilities
                        if monster.is_paladin then
                            -- Paladin's Light: 20% chance to activate (blinds player and heals paladin)
                            if math.random(1, 5) == 1 and monster.stamina >= 10 then
                                monster.stamina = monster.stamina - 10
                                player.blinded_turns = 2
                                local heal_amount = math.min(10, monster.max_hp - monster.hp)
                                monster.hp = monster.hp + heal_amount
                                action_text = action_text .. "✨ " .. monster.name .. " uses Paladin's Light! You are blinded and they heal " .. heal_amount .. " HP!\n"
                            end
                            
                            -- Reflect: 25% chance when below 50% HP (reflects next player attack)
                            if monster.hp <= monster.max_hp / 2 and not monster.reflect_active and math.random(1, 4) == 1 and monster.stamina >= 8 then
                                monster.stamina = monster.stamina - 8
                                monster.reflect_active = true
                                monster.reflect_percent = 70
                                action_text = action_text .. "� " .. monster.name .. " activates Reflect! Next attack will be partially reflected!\n"
                            end
                            
                            -- Clarity: 15% chance to boost next attack
                            if math.random(1, 7) == 1 and monster.stamina >= 8 then
                                monster.stamina = monster.stamina - 8
                                monster.clarity_turns = 1
                                action_text = action_text .. "🧘 " .. monster.name .. " uses Clarity! Next attack has increased power and accuracy!\n"
                            end
                        end

                        -- Monster attack logic
                        local attacks_this_turn = 1

                        -- Goblin double attack if stamina >= 6
                        if monster.name == "Goblin" and monster.stamina >= 6 and math.random(1, 3) == 1 then
                            monster.stamina = monster.stamina - 6
                            attacks_this_turn = 2
                            action_text = action_text .. "👹 " .. monster.name .. " prepares a double attack!\n"
                        end

                        for attack_num = 1, attacks_this_turn do
                            if monster.hp <= 0 or player.hp <= 0 or player.inshop then break end

                            -- Skip attack if player is still undetected
                            if undetected then
                                if attacks_this_turn == 1 then
                                    action_text = action_text ..
                                    "👁️  " .. monster.name .. " has nothing left to pickpocket.\n"
                                end
                                break
                            end

                            -- Skip attack if monster is stunned or blinded
                            if (monster.stunned_turns and monster.stunned_turns > 0) or (monster.blinded_turns and monster.blinded_turns > 0) then
                                if attacks_this_turn == 1 then
                                    if monster.stunned_turns and monster.stunned_turns > 0 then
                                        action_text = action_text ..
                                        "💫 " .. monster.name .. " is stunned and cannot attack!\n"
                                    elseif monster.blinded_turns and monster.blinded_turns > 0 then
                                        action_text = action_text ..
                                        "😵 " .. monster.name .. " is blinded and cannot attack!\n"
                                    end
                                end
                                break
                            end

                            local base_dmg = math.random(1, monster.power)
                            
                            -- Apply Holy Aura power bonus for paladins
                            if monster.is_paladin and monster.holy_aura_turns and monster.holy_aura_turns > 0 then
                                base_dmg = base_dmg + 5
                            end
                            
                            local dmg = math.max(1, base_dmg - player.defense)

                            -- Apply special monster behaviors
                            local attack_modifier = ""
                            if monster.name == "Skeleton" and monster.stamina > 0 then
                                -- Skeleton has +4 defense while it has stamina
                                -- Already applied in damage calculation
                            elseif monster.name == "Bat" and math.random(1, 3) == 1 and monster.stamina >= 2 then
                                monster.stamina = monster.stamina - 2
                                attack_modifier = "💨 " .. monster.name .. " dodged and counter-attacked! (stamina -2)\n"
                                dmg = dmg + 2
                            elseif monster.name == "Worm" and monster.thick_hide_turns > 0 then
                                -- Reduce power and accuracy during thick hide
                                local reduced_power = math.max(1, monster.power - 5)
                                base_dmg = math.random(1, reduced_power)
                                dmg = math.max(1, base_dmg - player.defense - 10) -- +10 defense from thick hide
                            elseif monster.name == "Goblin" and attacks_this_turn == 2 then
                                -- Reduced accuracy for double attack
                                if math.random(1, 100) <= 40 then -- 40% miss chance for double attack
                                    dmg = 0
                                    attack_modifier = "💨 " ..
                                    monster.name .. "'s attack misses due to reduced accuracy!\n"
                                else
                                    dmg = math.max(1, dmg + 1) -- Slightly increased power
                                end
                            elseif monster.is_boss and math.random(1, 3) == 1 then
                                attack_modifier = "🔥 " .. monster.name .. " unleashes a devastating attack!\n"
                                dmg = math.floor(dmg * 1.5)
                            elseif monster.is_paladin then
                                -- Check for Clarity boost
                                if monster.clarity_turns and monster.clarity_turns > 0 then
                                    dmg = dmg + 5 -- +5 power from clarity
                                    attack_modifier = "🧘 " .. monster.name .. " attacks with Clarity's power!\n"
                                    monster.clarity_turns = monster.clarity_turns - 1
                                end
                            end

                            if attack_modifier ~= "" then
                                action_text = action_text .. attack_modifier
                            end

                            -- Apply guaranteed dodge first: certain abilities (e.g. Backstab)
                            -- grant a free dodge on the next incoming attack.  If this
                            -- flag is set, ignore all damage and consume the flag.
                            if player.guaranteed_dodge_next then
                                action_text = action_text .. "💨 You effortlessly evade the attack!\n"
                                dmg = 0
                                -- Reset the flag so the next attack can hit normally
                                player.guaranteed_dodge_next = false
                            else
                                -- Apply player's dodge chance (capped at 80%) and any
                                -- temporary bonus from abilities like Blood Strike.  A
                                -- random roll less than or equal to the effective
                                -- dodge value means the attack misses.
                                local effective_dodge = player.dodge + (player.temp_dodge_bonus or 0)
                                if effective_dodge > 80 then
                                    effective_dodge = 80
                                end
                                local dodge_roll = math.random(1, 100)
                                if dodge_roll <= effective_dodge then
                                    action_text = action_text .. "💨 You dodged the attack!\n"
                                    dmg = 0
                                end
                                -- Consume temporary dodge bonus after it has been applied
                                if player.temp_dodge_bonus and player.temp_dodge_bonus > 0 then
                                    player.temp_dodge_bonus = 0
                                end
                            end

                            if dmg > 0 then
                                -- Apply damage reduction from player abilities
                                if player.shield_wall_turns and player.shield_wall_turns > 0 then
                                    dmg = math.ceil(dmg * 0.5)
                                    action_text = action_text .. "🛡️  Shield Wall reduces damage!\n"
                                end
                                if player.holy_aura_turns and player.holy_aura_turns > 0 then
                                    dmg = math.ceil(dmg * 0.7)
                                    action_text = action_text .. "✨ Holy Aura reduces damage!\n"
                                end
                                if player.reflect_active then
                                    local reflected = math.floor(dmg * (player.reflect_percent / 100) * 0.5)
                                    local healed = math.floor(dmg * (player.reflect_percent / 100) * 0.5)
                                    dmg = dmg - math.floor(dmg * (player.reflect_percent / 100))
                                    monster.hp = monster.hp - reflected
                                    player.hp = math.min(player.max_hp, player.hp + healed)
                                    action_text = action_text ..
                                    "🔁 Reflect negates " ..
                                    player.reflect_percent ..
                                    "% damage, reflecting " .. reflected .. " and healing " .. healed .. "!\n"
                                    player.reflect_active = false
                                    player.reflect_percent = 0
                                end

                                if attacks_this_turn == 2 then
                                    action_text = action_text ..
                                    "💢 " ..
                                    monster.name ..
                                    " hits you with attack " .. attack_num .. " for " .. dmg .. " damage!\n"
                                else
                                    action_text = action_text ..
                                    "💢 " .. monster.name .. " hits you for " .. dmg .. " damage!\n"
                                end
                                player.hp = player.hp - dmg

                                -- Skeleton loses stamina when hit (if player dealt damage this turn)
                                if monster.name == "Skeleton" and monster.stamina > 0 then
                                    -- This should be triggered when player attacks, will implement below
                                end
                            end

                            -- Decrement status effect timers
                            if monster.blinded_turns and monster.blinded_turns > 0 then
                                monster.blinded_turns = monster.blinded_turns - 1
                            end
                            if monster.stunned_turns and monster.stunned_turns > 0 then
                                monster.stunned_turns = monster.stunned_turns - 1
                            end
                            if monster.thick_hide_turns and monster.thick_hide_turns > 0 then
                                monster.thick_hide_turns = monster.thick_hide_turns - 1
                            end
                            
                            -- Decrement paladin status effect timers
                            if monster.reflect_active and monster.reflect_turns and monster.reflect_turns > 0 then
                                monster.reflect_turns = monster.reflect_turns - 1
                                if monster.reflect_turns <= 0 then
                                    monster.reflect_active = false
                                    monster.reflect_percent = 0
                                end
                            end
                            if monster.clarity_turns and monster.clarity_turns > 0 then
                                monster.clarity_turns = monster.clarity_turns - 1
                            end
                        end
                        
                        -- Monster stamina regeneration at end of their turn
                        if monster.hp > 0 then
                            -- Monsters regenerate 2 stamina per turn (basic regen)
                            local monster_regen = 2
                            monster.stamina = math.min(monster.max_stamina, monster.stamina + monster_regen)
                        end

                        -- Decrement player status effect timers
                        if player.blinded_turns and player.blinded_turns > 0 then
                            player.blinded_turns = player.blinded_turns - 1
                        end
                        if player.shield_wall_turns and player.shield_wall_turns > 0 then
                            player.shield_wall_turns = player.shield_wall_turns - 1
                        end
                        if player.holy_aura_turns and player.holy_aura_turns > 0 then
                            player.holy_aura_turns = player.holy_aura_turns - 1
                        end
                        if player.blood_boiling_turns and player.blood_boiling_turns > 0 then
                            player.blood_boiling_turns = player.blood_boiling_turns - 1
                        end
                    end -- Close the skip_turn check

                    last_action_result = action_text
                    -- Save the most recent action log for use when displaying a
                    -- death recap.  This variable persists across encounters
                    -- within run_arena.
                    final_action_log = last_action_result
                end

                if player.hp > 0 and player.inshop == false and monster.hp <= 0 then
                    -- The monster has been defeated.  Clear the combat log so that
                    -- only the reward summary is shown.  This keeps the console
                    -- uncluttered and focuses attention on the loot and XP gain.
                    clear_console()
                    -- Display an appropriate victory message
                    if monster.is_boss then
                        print("🏆 YOU DEFEATED THE BOSS! 🏆")
                        print("✅ " .. monster.name .. " has fallen!")
                    else
                        print("✅ You defeated the " .. monster.name .. "!")
                        -- Increment kill counter for boss spawning
                        for name, _ in pairs(player.monster_kills or {}) do
                            if monster.name == name then
                                player.monster_kills[name] = (player.monster_kills[name] or 0) + 1
                                if player.monster_kills[name] == 10 then
                                    print("⚠️  You've killed 10 " .. name .. "s! A boss may appear soon...")
                                end
                                break
                            end
                        end
                    end

                    -- Handle Blood Ritual completion
                    if player.blood_ritual_active then
                        print("🩸 BLOOD RITUAL COMPLETE 🩸")
                        if not player.blood_ritual_completed_before then
                            player.blood_ritual_completed_before = true
                            print("🔻 You have completed your first Blood Ritual...")
                        end
                        player.blood_ritual_active = false
                        player.blood_ritual_persistent = false
                        -- Keep the permanent stat changes gained during the ritual
                        print("🩸 The Blood has made you stronger: +" .. player.blood_ritual_power_bonus .. " Power, +" ..
                              player.blood_ritual_power_bonus .. " Accuracy, +" .. player.blood_ritual_sneak_bonus .. 
                              " Sneak, " .. player.blood_ritual_defense_bonus .. " Defense")
                    end

                    -- Award coins and display the drop.  Luck grants extra
                    -- coins: each point of luck adds a random bonus up to
                    -- your luck value.  This encourages investing in luck
                    -- skills and equipment.
                    local bonus_coins = math.random(0, player.luck)
                    local total_coins = monster.coinDrop + bonus_coins

                    -- Check jackpot status before resetting it
                    local jackpot_was_active = player.jackpot_active

                    -- Apply jackpot bonus if active - scales with Lucky skill points
                    if player.jackpot_active then
                        local lucky_points = player.skills["Lucky"] or 0
                        local jackpot_bonus = math.floor(lucky_points * 2) -- 2 coins per Lucky skill point
                        total_coins = total_coins + jackpot_bonus
                        player.jackpot_active = false              -- Reset the flag after use
                        print("🍀 JACKPOT! +" .. jackpot_bonus .. " bonus coins from luck!")
                    end

                    player.coins = player.coins + total_coins
                    if bonus_coins > 0 then
                        print("💰 You found \27[33m" ..
                        total_coins ..
                        " coins\27[0m! (" ..
                        monster.coinDrop ..
                        "+" .. bonus_coins .. " from luck) Total: \27[33m" .. player.coins .. "\27[0m")
                    else
                        print("💰 You found \27[33m" ..
                        total_coins .. " coins\27[0m! Total: \27[33m" .. player.coins .. "\27[0m")
                    end

                    -- Award experience and capture whether the player leveled up
                    local leveled_up = player:gain_xp(monster.xpDrop)
                    -- Show XP gain with an up arrow and the current level on the right
                    print("\27[34m⬆️  +" .. monster.xpDrop .. " XP  | Level " .. player.level .. "\27[0m")
                    if leveled_up then
                        -- Provide a detailed level up summary instead of a flat stat increase.
                        print("\27[34m🎉 Leveled up to level " ..
                        player.level .. "!\27[0m +10 Max HP, +1 Max Stamina, +1 Skill Point.")
                        print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
                    end
                    -- If this was a boss, drop its unique item and increment kill count
                    if monster.is_boss then
                        local loot = boss_unique_items[monster.name]
                        if loot then
                            boss_kill_counts[monster.name] = (boss_kill_counts[monster.name] or 0) + 1
                            -- Prefix unique boss drops with a rarity symbol.  Boss
                            -- items are considered rare by default.
                            local sym = get_rarity_symbol("rare")
                            print("🎁 The " .. monster.name .. " dropped " .. sym .. " " .. loot.name .. "!")
                            player:add_temp_item(loot)
                            -- Grant special abilities if provided by the loot
                            if loot.grant_heal then
                                player.heal_ability = true
                                player.abilities_enabled.heal = true
                                player:unlock_ability("Heal")
                                print("✨ You learned how to heal yourself!")
                            end
                            if loot.grant_lifesteal then
                                player.lifesteal_ability = true
                                player:unlock_ability("Lifesteal")
                                print("🧛 You gained a lifesteal ability! Attacks will heal you.")
                            end
                        end
                    end

                    -- Random item drops from monsters.  There is a chance that any
                    -- defeated monster will drop an item.  The rarity of the drop
                    -- scales with rarity: common items drop most often, rare items
                    -- drop infrequently.
                    do
                        -- Luck increases both the chance of an item dropping and
                        -- the likelihood of higher rarities.  Base drop chance is
                        -- 12%; each 2 points of luck adds ~1% up to a maximum of 40%.
                        local drop_threshold = 12 + math.floor(player.luck / 2)
                        if drop_threshold > 40 then drop_threshold = 40 end

                        -- Jackpot provides an extra roll for drop chance (not guaranteed)
                        local extra_roll = jackpot_was_active
                        local got_drop = false

                        -- First roll for item drop
                        if math.random(100) <= drop_threshold then
                            got_drop = true
                        elseif extra_roll then
                            -- Extra roll from jackpot if first roll failed
                            if math.random(100) <= drop_threshold then
                                got_drop = true
                                print("🍀 JACKPOT! Extra roll succeeded!")
                            end
                        end

                        if got_drop then
                            -- Rarity thresholds: rare starts at 5% and gains +1% per
                            -- point of luck (cap at 25%).  Uncommon starts at 30%
                            -- and gains +2% per luck point (cap at 80%).  Any roll
                            -- above these becomes common.
                            local rarity_roll = math.random(1, 100)
                            local rare_threshold = 5 + player.luck
                            if rare_threshold > 25 then rare_threshold = 25 end
                            local uncommon_threshold = 30 + player.luck * 2
                            if uncommon_threshold > 80 then uncommon_threshold = 80 end
                            local rarity
                            if rarity_roll <= rare_threshold then
                                rarity = "rare"
                            elseif rarity_roll <= rare_threshold + uncommon_threshold then
                                rarity = "uncommon"
                            else
                                rarity = "common"
                            end
                            -- Build list of items matching the chosen rarity
                            local pool = {}
                            for _, itm in ipairs(item_pool) do
                                if itm.rarity == rarity then
                                    table.insert(pool, itm)
                                end
                            end
                            if #pool > 0 then
                                local drop = pool[math.random(#pool)]
                                print("📦 The monster dropped " ..
                                get_rarity_symbol(drop.rarity) .. " " .. drop.name .. "!")
                                player:add_temp_item(drop)
                            end
                        end
                    end

                    -- Post‑combat choice: fight another or return to the shop.                      Inform the player
                    -- that choosing to continue fighting grants a bonus.  This tip
                    -- encourages riskier play by rewarding consecutive battles.
                    -- Show a random tip
                    local tip = tips[math.random(#tips)]
                    print("Tip:\27[0m " .. tip)
                    print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
                    local xp_needed_for_next = 100 + (player.level - 1) * 10
                    print("❤️  HP: " ..
                    player.hp ..
                    "/" ..
                    player.max_hp ..
                    " | ⚡ Stamina: " ..
                    player.stamina ..
                    "/" .. player.max_stamina .. " | " .. player.xp .. "/" .. xp_needed_for_next .. " XP")
                    print("  ❤️   " ..
                    player.health_potions ..
                    " | ⚡  " ..
                    player.stamina_potions ..
                    " | 🧪  " .. player.evasion_potions .. " | 💰  " .. player.coins .. " | 🌟  " .. player.skill_points)

                    print("\n1. ⚔️  Fight another monster (+20 coins)")
                    print("2. 🏪 Return to shop (+20 HP)")
                    io.write("\nWhat would you like to do? ")
                    local post_choice = io.read()
                    if post_choice == "2" then
                        -- Moving to the shop after a victory grants hp
                        player.inshop = true
                        local heal = 20
                        player.hp = math.min(player.max_hp, player.hp + heal)
                        print("🏪 Returning to the shop! You recover " .. heal .. " HP.")
                        clear_for_transition()
                    else
                        -- Reward the player for staying to fight
                        player.coins = player.coins + 20
                        print("💰 Bonus: You gained 20 coins for continuing to fight! Total: " .. player.coins)
                        clear_for_transition()
                    end
                elseif player.inshop == false and player.hp > 0 then
                    -- Obsolete branch retained for readability; death handling
                    -- occurs after the loop below.
                end
            end -- Close the else block from the random event check
        end
        -- After the arena loop concludes, if the player died in combat
        -- (and not because they fled to the shop), show the last recorded
        -- action log so they know what happened.  This message is
        -- captured during the fight and printed here.  We clear the
        -- console to isolate the death recap.
        if player.hp <= 0 and not player.inshop then
            clear_console()
            -- final_action_log is captured at the top of run_arena; if
            -- present, print it and a separator before the death notice.
            if final_action_log and final_action_log ~= "" then
                print(final_action_log)
                print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
            end
            print("☠️ You were defeated in combat!")
            print("")
            -- Clear any temporary items on death
            player.temp_items = {}
            print("Press Enter to view final statistics...")
            -- Wait for input to allow the player to read the recap
            local _ = io.read()
        end
    end

    -- Main Game Loop --
    clear_console()
    print("⚔️  Welcome to the Monster Arena! ⚔️\n")
    print("🎯 Defeat monsters, collect coins, level up, and upgrade your equipment!")
    print("💡 Tip: Kill 10 of the same monster type to face their boss!")
    print("⚠️  Warning: Each monster type has their own special ability!\n")
    print("Press Enter to begin...")
    local _ = io.read()

    while player.hp > 0 do
        if player.inshop then
            run_shop()
        else
            run_arena()
        end
    end

    -- When the main loop exits, the player has been defeated.  Print a
    -- concise summary immediately without prompting for additional input.
    -- Include the player’s final HP and stamina values so they can see
    -- how close they were to surviving.  Also summarize collected
    -- resources, monsters slain and bosses defeated.
    local total_monsters = 0
    for _, count in pairs(player.monster_kills or {}) do
        total_monsters = total_monsters + count
    end

    print("\n💀 You have been defeated! Final HP: " ..
    player.hp .. "/" .. player.max_hp .. " | Stamina: " .. player.stamina .. "/" .. player.max_stamina)
    print("Final Stats:")
    print("  Level: " .. player.level)
    print("  Coins Collected: " .. player.coins)
    print("  Monsters Killed: " .. total_monsters)
    print("  Items Collected: " .. #player.inventory)
    -- Display how many bosses were defeated and which ones.
    local any_bosses = false
    for name, count in pairs(player.boss_kills or {}) do
        if count > 0 then
            any_bosses = true
            break
        end
    end
    if any_bosses then
        print("  Bosses Defeated:")
        for name, count in pairs(boss_kill_counts) do
            if count > 0 then
                print("    " .. name .. ": " .. count)
            end
        end
    else
        print("  Bosses Defeated: none")
    end
end

-- Restart game function
function restart_game()
    -- Reset player properties to initial state without replacing the table
    -- This preserves the methods that were added with the colon syntax
    player.name = "You"
    player.level = 1
    player.hp = 100
    player.max_hp = 100
    player.xp = 0
    player.total_xp = 0
    player.power = 10
    player.defense = 0
    player.accuracy = 0
    player.dodge = 5
    player.health_potions = 0
    player.stamina_potions = 0
    player.coins = 50
    player.inshop = false
    player.inventory = {}
    player.evasion_potions = 0
    player.stamina = 10
    player.max_stamina = 10
    player.stamina_regen = 2
    player.heal_ability = false
    player.lifesteal_ability = false
    player.blood_strike_ability = false
    player.temp_dodge_bonus = 0
    player.guaranteed_dodge_next = false
    player.sneak = 0
    player.luck = 0
    player.skill_points = 0
    player.skills = {
        Fighter = 0,
        Elusive = 0,
        Focus = 0,
        Fortitude = 0,
        Assassin = 0,
        Tank = 0,
        Lucky = 0,
        Berserk = 0,
        ["Blood Oath"] = 0,
        Radiance = 0
    }
    player.bloodmark = false
    player.paladinmark = false
    player.blood_drain_ability = false
    player.blood_boil_ability = false
    player.blood_boiling_turns = 0
    player.paladin_light_ability = false
    player.reflect_ability = false
    player.clarity_ability = false
    player.reflect_active = false
    player.reflect_percent = 0
    player.extra_stock = 0
    -- Inventory management system
    player.max_inventory = 5            -- Starting inventory limit
    player.temp_items = {}              -- Items obtained during arena runs (not equipped yet)
    -- Upgrade counters
    player.inventory_upgrades = 0       -- Number of inventory upgrades purchased
    player.health_potion_upgrades = 0   -- Number of health potion upgrades
    player.stamina_potion_upgrades = 0  -- Number of stamina potion upgrades
    player.evasion_potion_upgrades = 0  -- Number of evasion potion upgrades
    player.evasion_bonus_active = false -- Temporary shop bonus from using upgraded evasion potion
    player.merchant_bangle = 0
    player.shield_wall_turns = 0
    player.holy_aura_turns = 0
    player.blinded_turns = 0
    player.jackpot_active = false
    player.blood_ritual_active = false
    player.blood_ritual_persistent = false
    player.blood_ritual_stacks = 0
    player.blood_ritual_completed_before = false
    player.blood_ritual_power_bonus = 0
    player.blood_ritual_sneak_bonus = 0
    player.blood_ritual_defense_bonus = 0
    player.blood_ritual_maxhp_bonus = 0
    player.blood_ability_cost_reduction = 0
    player.abilities_enabled = {
        attack = true,
        strong_attack = true,
        blood_strike = false,
        heal = false,
        blood_drain = false,
        blood_boil = false,
        paladin_light = false,
        reflect = false,
        clarity = false,
        shield_bash = false,
        shadow_step = false,
        meditate = false,
        second_wind = false,
        poisoned_strike = false,
        shield_wall = false,
        jackpot = false,
        frenzy = false,
        blood_ritual = false,
        holy_ritual = false
    }
    player.max_abilities = 4
    player.total_xp = 0
    -- Progress tracking for death screen statistics
    player.total_items_obtained = 0
    player.total_abilities_unlocked = 2
    player.skill_sets_learned = 0
    player.total_damage_dealt = 0
    player.total_damage_taken = 0
    -- Monster kill tracking
    player.monster_kills = {
        Bat = 0,
        Goblin = 0,
        Skeleton = 0,
        Slime = 0,
        Worm = 0
    }
    -- Boss kill tracking
    player.boss_kills = {
        ["Goblin King"] = 0,
        ["Slime Lord"] = 0,
        ["Skeleton Warrior"] = 0,
        ["Vampire Bat"] = 0,
        ["Giant Worm"] = 0
    }
    -- Additional flags
    player.paladins_hostile = false
    player.immediate_paladin_combat = false
    player.skill_books = {}
    player.cultists_encountered = false
    player.blood_shop_expansions = 0

    -- Reset monster kill tracking
    monster_kills = {
        Goblin = 0,
        Slime = 0,
        Skeleton = 0,
        Bat = 0,
        Worm = 0
    }

    -- Reset boss kill counts
    boss_kill_counts = {
        ["Goblin King"] = 0,
        ["Slime Lord"] = 0,
        ["Skeleton Warrior"] = 0,
        ["Vampire Bat"] = 0,
        ["Giant Worm"] = 0
    }

    -- Clear any pending messages
    pending_flee_message = nil

    return true
end

-- Function to count how many abilities are currently enabled
function count_enabled_abilities()
    local count = 0
    for key, enabled in pairs(player.abilities_enabled) do
        -- Don't count attack and strong attack toward the limit
        if enabled and key ~= "attack" and key ~= "strong_attack" then
            count = count + 1
        end
    end
    return count
end

-- Check for restart input
function check_restart_input(input)
    if input and string.upper(input:gsub("%s+", "")) == "R" then
        clear_console()
        print("🔄 Restarting game...")
        io.write("Press Enter to continue...")
        local _ = io.read()
        restart_game()
        return true
    end
    return false
end

-- Main Game Loop --
while true do
    clear_console()
    print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
    print("\n         ⚔️   Welcome to the Arena  ⚔️\n")
    print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
    print("")
    print("        🏆 Step inside and claim glory!")
    print("            or find your own path...")
    print("")
    print("\27[38;5;240m════════════════════════════════════════════════\27[0m")
    print(" ")
    print("  \27[38;5;240m💡 Tip: Press 'R' then Enter at any menu to restart the game!\27[0m")
    print("\n            Press Enter to begin...")
    print("          (Type 'test' for Test Mode)")
    local start_input = io.read()

    -- Check for test mode
    if start_input == "test" then
        -- Comprehensive Test Mode setup
        player.hp = 999
        player.max_hp = 999
        player.stamina = 100
        player.max_stamina = 100
        player.stamina_regen = 10
        player.power = 50
        player.defense = 50
        player.accuracy = 50
        player.dodge = 50
        player.sneak = 50
        player.luck = 50
        player.coins = 9999
        player.health_potions = 99
        player.stamina_potions = 99
        player.evasion_potions = 99
        player.skill_points = 99
        
        -- Unlock all special marks and abilities
        player.bloodmark = true
        player.paladinmark = true
        player.focus_unlocked = true
        player.scholar_paid = true
        
        -- Set skill levels to unlock all abilities
        for name, _ in pairs(player.skills) do
            player.skills[name] = 5
        end
        
        -- Unlock all special abilities
        player.blood_strike_ability = true
        player.heal_ability = true
        player.lifesteal_ability = true
        player.blood_drain_ability = true
        player.blood_boil_ability = true
        player.paladin_light_ability = true
        player.reflect_ability = true
        player.clarity_ability = true
        
        -- Enable basic abilities by default (others can be toggled in the abilities menu)
        player.abilities_enabled.attack = true
        player.abilities_enabled.strong_attack = true
        
        print("TEST MODE ACTIVATED")
        io.write("\nPress Enter to start testing...")
        io.read()
    end

    -- Check for restart at start menu
    if check_restart_input(start_input) then
        -- restart_game() already called, continue loop
    else
        -- Normal game loop
        while player.hp > 0 do
            if player.inshop then
                run_shop()
            else
                run_arena()
            end
        end

        -- Game over - show detailed statistics and death message
        clear_console()
        print("💀 ════════════════════════════════════════════════ 💀")
        print("                    GAME OVER")
        print("💀 ════════════════════════════════════════════════ 💀")
        print("")
        print("📊  FINAL STATISTICS")
        print("═══════════════════")
        print(string.format("🌟  Level Reached: %d", player.level))
        print(string.format("⬆️  Total XP Earned: %d", player.total_xp))
        print(string.format("💰 Coins Collected: %d", player.coins))
        print(string.format("📚 Skill Sets Learned: %d", player:calculate_skill_sets_learned()))
        print(string.format("🧬 Abilities Unlocked: %d", player.total_abilities_unlocked))
        print(string.format("💼 Items Obtained: %d", player.total_items_obtained))
        print("")
        print("⚔️  COMBAT RECORD")
        print("═════════════════")

        -- Calculate total monsters killed
        local total_monsters = 0
        local total_bosses = 0
        for monster_type, count in pairs(player.monster_kills or {}) do
            total_monsters = total_monsters + count
        end
        for boss_type, count in pairs(player.boss_kills or {}) do
            total_bosses = total_bosses + count
        end

        print(string.format("🦇 Bats Defeated: %d", player.monster_kills["Bat"] or 0))
        print(string.format("👹 Goblins Defeated: %d", player.monster_kills["Goblin"] or 0))
        print(string.format("💀 Skeletons Defeated: %d", player.monster_kills["Skeleton"] or 0))
        print(string.format("💚 Slimes Defeated: %d", player.monster_kills["Slime"] or 0))
        print(string.format("🐛 Worms Defeated: %d", player.monster_kills["Worm"] or 0))
        print(string.format("👑 Total Bosses Defeated: %d", total_bosses))
        print("═════════════════")
        print(string.format("🗡  Total Damage Dealt: %d", player.total_damage_dealt or 0))
        print(string.format("💢 Total Damage Taken: %d", player.total_damage_taken or 0))


        if total_bosses > 0 then
            print("� Boss Victories:")
            for boss_type, count in pairs(player.boss_kills or {}) do
                if count > 0 then
                    print(string.format("   • %s Boss: %d defeated", boss_type, count))
                end
            end
            print("")
        end
        print("")
        print("Press 'R' to restart your journey or any other key to exit...")
        local game_over_input = io.read()
        if not check_restart_input(game_over_input) then
            break -- Exit the outer loop to end the program
        end
    end
end
