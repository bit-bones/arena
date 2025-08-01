math.randomseed(os.time())

-- Clear console function
function clear_console()
    -- Attempt to clear the console.  On Unix-like systems use "clear";
    -- on Windows systems, "cls" may be required.  os.execute returns
    -- system-dependent values which we ignore.
    os.execute("clear")
    -- For Windows compatibility, you could use: os.execute("cls")
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
    power = 10,
    defense = 0,
    accuracy = 0,
    -- Dodge chance in percent.  Each point increases the chance to
    -- avoid an incoming attack by roughly one percentage point.  This
    -- value is capped during combat so the player can never reach
    -- complete invulnerability.
    -- Start with a small dodge chance so the player has a baseline
    -- ability to avoid attacks.  Additional dodge can be gained from
    -- items.  Starting value increased from 0 to 5 for a fairer
    -- baseline.
    dodge = 5,
    -- Number of health potions carried.  Health potions can be used
    -- during combat to restore HP.
    health_potions = 0,
    -- Number of stamina potions carried.  Stamina potions restore a
    -- portion of the player's stamina.
    stamina_potions = 0,
    -- Start with some coins so the player can purchase basic items on
    -- their first shop visit.  Increased from 0 to 50.
    coins = 50,
    inshop = false,
    inventory = {},
    -- Number of evasion potions carried.  These allow a safe escape
    -- from combat.
    evasion_potions = 0,
    -- Current stamina.  Certain actions (strong attacks, healing
    -- abilities) consume stamina.  Stamina regenerates after each
    -- player action by stamina_regen.
    stamina = 10,
    max_stamina = 10,
    stamina_regen = 2,
    -- Ability flags unlocked by unique boss items.  heal_ability
    -- grants access to a self‑heal action that consumes stamina, and
    -- lifesteal_ability siphons a portion of damage dealt back as HP.
    heal_ability = false,
    lifesteal_ability = false
}

-- Monster kill tracking for boss spawning
monster_kills = {
    Goblin = 0,
    Slime = 0,
    Skeleton = 0,
    Bat = 0,
    Worm = 0
}

-- Track how many times each boss has been defeated.  This table is
-- keyed by the full boss name (e.g. "Goblin King").  It allows the
-- final game summary to report which bosses were slain and how
-- often.
boss_kill_counts = {
    ["Goblin King"] = 0,
    ["Slime Lord"] = 0,
    ["Skeleton Warrior"] = 0,
    ["Vampire Bat"] = 0,
    ["Giant Worm"] = 0
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

function player:attack(target)
    local hit_chance = math.random(1, 20) + math.floor(self.accuracy / 2)
    local dodge_chance = math.random(1, 10) + (target.level or 1)
    if hit_chance <= dodge_chance then
        return false
    end

    local min_dmg = math.max(1, 5 + self.accuracy)
    local dmg = math.random(min_dmg, self.power)
    target.hp = target.hp - dmg
    -- If the player has a lifesteal ability, heal a portion of the
    -- damage dealt.  Lifesteal heals for half of the damage inflicted.
    if self.lifesteal_ability and dmg > 0 then
        local heal = math.floor(dmg / 2)
        self.hp = math.min(self.max_hp, self.hp + heal)
    end
    return true, dmg
end

function player:strong_attack(target)
    local hit_chance = math.random(1, 20) + math.floor(self.accuracy / 2)
    local dodge_chance = math.random(1, 10) + (target.level or 1)
    if hit_chance <= dodge_chance then
        return false
    end

    local min_dmg = math.max(1, 5 + self.accuracy)
    local dmg = math.random(min_dmg, self.power + 3)
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
function player:gain_xp(amount)
    -- accumulate experience
    self.xp = self.xp + amount
    local level_up = false
    -- check for level up
    while self.xp >= 100 do
        self.xp = self.xp - 100
        self.level = self.level + 1
        -- raise core stats on level up
        self.power = self.power + 1
        self.defense = self.defense + 1
        self.accuracy = self.accuracy + 1
        level_up = true
    end
    return level_up
end

function player:add_item(item)
    table.insert(self.inventory, item)
    -- Apply stat bonuses
    self.power = self.power + (item.power_bonus or 0)
    self.defense = self.defense + (item.defense_bonus or 0)
    self.accuracy = self.accuracy + (item.accuracy_bonus or 0)
    -- Dodge bonus may be positive or negative.  Cap will be applied
    -- during combat when rolling to dodge.
    self.dodge = self.dodge + (item.dodge_bonus or 0)
    -- Increase maximum HP if provided and fully heal to new maximum.
    if item.max_hp_bonus then
        self.max_hp = self.max_hp + item.max_hp_bonus
        self.hp = self.max_hp
    end
    -- Increase maximum stamina and/or regeneration rate if provided.
    if item.max_stamina_bonus then
        self.max_stamina = self.max_stamina + item.max_stamina_bonus
        -- replenish current stamina to new maximum
        self.stamina = self.max_stamina
    end
    if item.stamina_regen_bonus then
        self.stamina_regen = self.stamina_regen + item.stamina_regen_bonus
    end

    print("✅ " .. item.name .. " added to inventory!")
    if item.power_bonus and item.power_bonus > 0 then
        print("  💪 Power increased by " .. item.power_bonus)
    end
    if item.defense_bonus and item.defense_bonus > 0 then
        print("  🛡️  Defense increased by " .. item.defense_bonus)
    end
    if item.accuracy_bonus and item.accuracy_bonus > 0 then
        print("  🎯 Accuracy increased by " .. item.accuracy_bonus)
    end
    if item.max_hp_bonus and item.max_hp_bonus > 0 then
        print("  ❤️  Max HP increased by " .. item.max_hp_bonus)
    end
    if item.dodge_bonus and item.dodge_bonus ~= 0 then
        if item.dodge_bonus > 0 then
            print("  🌀 Dodge increased by " .. item.dodge_bonus)
        else
            -- Show negative dodge as a penalty
            print("  🌀 Dodge decreased by " .. math.abs(item.dodge_bonus))
        end
    end
    if item.max_stamina_bonus and item.max_stamina_bonus > 0 then
        print("  ⚡ Max Stamina increased by " .. item.max_stamina_bonus)
    end
    if item.stamina_regen_bonus and item.stamina_regen_bonus > 0 then
        print("  ♻️  Stamina Regen increased by " .. item.stamina_regen_bonus)
    end
end

function player:use_evasion_potion()
    if self.evasion_potions > 0 then
        self.evasion_potions = self.evasion_potions - 1
        self.inshop = true
        print("💨 Used Evasion Potion! You slip away safely to the shop!")
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
        price = 30,
        defense_bonus = 2,
        power_bonus = -1,
        -- Heavy shields reduce your ability to dodge.
        dodge_bonus = -5,
        description = "+2 Defense, -1 Power, -5 Dodge"
    },
    {
        name = "Simple Bow",
        rarity = "common",
        price = 20,
        accuracy_bonus = 1,
        description = "+1 Accuracy"
    },
    -- Additional common items that enhance dodge.  These provide a
    -- modest chance to avoid attacks and in some cases reduce your
    -- defense due to lighter armour.
    {
        name = "Cloth Hood",
        rarity = "common",
        price = 30,
        dodge_bonus = 10,
        defense_bonus = -1,
        description = "+10 Dodge, -1 Defense"
    },
    {
        name = "Leather Boots",
        rarity = "common",
        price = 35,
        dodge_bonus = 10,
        description = "+10 Dodge"
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
        power_bonus = -1,
        dodge_bonus = -8,
        description = "+4 Defense, -1 Power, -8 Dodge"
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
        defense_bonus = -2,
        description = "+20 Dodge, -2 Defense"
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
        description = "+8 Power"
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
        defense_bonus = -3,
        accuracy_bonus = 2,
        description = "+30 Dodge, -3 Defense, +2 Accuracy"
    },
    {
        name = "Phantom Boots",
        rarity = "rare",
        price = 190,
        dodge_bonus = 30,
        defense_bonus = -2,
        description = "+30 Dodge, -2 Defense"
    },
    {
        name = "Mystic Stone",
        rarity = "rare",
        price = 250,
        max_stamina_bonus = 5,
        stamina_regen_bonus = 1,
        description = "+5 Max Stamina, +1 Stamina Regen"
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
        dodge_bonus = 5,
        accuracy_bonus = 1,
        description = "+5 Dodge, +1 Accuracy"
    },
    {
        name = "Old Cloak",
        rarity = "common",
        price = 30,
        defense_bonus = 1,
        dodge_bonus = 5,
        description = "+1 Defense, +5 Dodge"
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
        dodge_bonus = 10,
        description = "+4 Power, +5 Accuracy, +10 Dodge"
    },
    {
        name = "Sacred Scroll",
        rarity = "rare",
        price = 250,
        max_hp_bonus = 10,
        max_stamina_bonus = 5,
        stamina_regen_bonus = 1,
        description = "+10 Max HP, +5 Max Stamina, +1 Stamina Regen"
    },
    {
        name = "Chainmail Armor",
        rarity = "rare",
        price = 260,
        defense_bonus = 15,
        dodge_bonus = -10,
        description = "+15 Defense, -10 Dodge"
    }
}

-- Generate random shop items
function generate_shop_items()
    local items = {}

    for i = 1, 3 do
        local roll = math.random(100)
        local rarity_pool = {}

        if roll <= 5 then -- 5% rare
            for _, item in ipairs(item_pool) do
                if item.rarity == "rare" then
                    table.insert(rarity_pool, item)
                end
            end
        elseif roll <= 30 then -- 25% uncommon
            for _, item in ipairs(item_pool) do
                if item.rarity == "uncommon" then
                    table.insert(rarity_pool, item)
                end
            end
        else -- 70% common
            for _, item in ipairs(item_pool) do
                if item.rarity == "common" then
                    table.insert(rarity_pool, item)
                end
            end
        end

        if #rarity_pool > 0 then
            table.insert(items, rarity_pool[math.random(#rarity_pool)])
        end
    end

    return items
end

-- Monster generator with levels and special abilities
function generate_monster()
    local names = { "Goblin", "Slime", "Skeleton", "Bat", "Worm" }
    local name = names[math.random(#names)]
    local level = math.random(1, math.max(1, player.level + 2))

    -- Check if boss should spawn (every 10 kills of same type)
    if monster_kills[name] >= 10 then
        monster_kills[name] = 0 -- Reset counter
        return generate_boss(name, level)
    end

    local base_hp = 25 + (level - 1) * 12
    local base_power = 8 + (level - 1) * 4
    local hp = base_hp + math.random(-3, 8)
    local power = base_power + math.random(-1, 4)
    -- Increase the baseline gold drop and scale it more aggressively
    -- with the monster's level.  Previously: random(3,8)+level*2.  Now:
    -- random between 5 and 12 plus 4 per level.
    local coinDrop = math.random(5, 12) + level * 4
    -- Scale experience more steeply with level so higher level monsters
    -- give proportionally more XP.  Previously: 30 + level*10.  Now:
    -- base 40 plus 15 per level.
    local xpDrop = 40 + level * 15

    -- Special abilities based on monster type
    local special_ability = ""
    if name == "Bat" then
        special_ability = "High dodge chance"
    elseif name == "Skeleton" then
        special_ability = "High defense"
        power = power - 2 -- Lower attack but higher defense
    elseif name == "Slime" then
        special_ability = "Regenerates HP"
    elseif name == "Goblin" then
        special_ability = "Aggressive attacker"
        power = power + 3 -- Higher attack
    elseif name == "Worm" then
        special_ability = "Thick hide"
    end

    return {
        name = name,
        level = level,
        hp = hp,
        max_hp = hp,
        power = power,
        coinDrop = coinDrop,
        xpDrop = xpDrop,
        is_boss = false,
        special_ability = special_ability
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
        coinDrop = coinDrop,
        xpDrop = xpDrop,
        is_boss = true,
        special_ability = "Boss: Multiple attacks"
    }
end

-- Shop function
function run_shop()
    -- Clear the screen and generate a fresh set of shop items once per shop visit
    clear_for_transition()
    local shop_items = generate_shop_items()
    
    -- Stay in the shop until the player chooses to return to the arena or runs out of HP
    while player.hp > 0 and player.inshop == true do
        -- Always clear the console at the start of each iteration so the menu
        -- appears on a clean screen.  This keeps the shop interface uncluttered.
        clear_console()
        -- If the player fled from combat, show how much damage was taken
        -- before presenting the shop menu.  This message is stored when
        -- fleeing and consumed here to avoid cluttering the arena output.
        if pending_flee_message ~= nil then
            print(pending_flee_message)
            print("------")
            pending_flee_message = nil
        end
        print("🏪 Welcome to the shop!")
        print("💰 Your coins: " .. player.coins)
        print("❤️  Health Potions: " .. player.health_potions .. " | ⚡ Stamina Potions: " .. player.stamina_potions .. " | 🧪 Evasion Potions: " .. player.evasion_potions)
        print("\nItems for sale:")
        -- Consumable potions for sale
        print("1. ❤️  Health Potion (+20 HP) \27[1;33m- 15 coins\27[0m")
        print("2. ⚡ Stamina Potion (+5 Stamina) \27[1;33m- 25 coins\27[0m")
        print("3. 🧪 Evasion Potion (safe escape) \27[1;33m- 25 coins\27[0m")

        -- Display the randomly generated equipment items
        for i, item in ipairs(shop_items) do
            local rarity_symbol = "🟤" -- default for common
            if item.rarity == "uncommon" then
                rarity_symbol = "🔷"
            elseif item.rarity == "rare" then
                rarity_symbol = "🔶"
            end
            -- Offset by 3 because the first three options are potions
            print((i + 3) .. ". " .. rarity_symbol .. " " .. item.name .. " (" .. item.description .. ") \27[1;33m-\27[0m " .. "\27[1;33m" .. item.price .. "\27[0m" .. " \27[1;33mcoins\27[0m")
        end

        -- Additional options: view inventory or return to arena
        print("\n" .. (#shop_items + 4) .. ". 🎒 View Inventory")
        print((#shop_items + 5) .. ". ⚔️  Return to Arena")

        io.write("\nWhat would you like to do? ")
        local choice = io.read()
        local choice_num = tonumber(choice)

        -- Process the player's choice.  Before displaying the outcome of each
        -- action, clear the screen again so that only the relevant result is
        -- shown.  After the message, prompt for Enter so the player can read
        -- it before returning to the main shop menu.
        if choice == "1" then
            clear_console()
            -- Purchase a health potion: adds to inventory rather than instantly healing
            if player.coins >= 15 then
                player.coins = player.coins - 15
                player.health_potions = player.health_potions + 1
                print("✅ Bought Health Potion! Total: " .. player.health_potions)
            else
                print("❌ Not enough coins! Need 15 coins.")
            end
            io.write("\nPress Enter to continue...")
            io.read()
        elseif choice == "2" then
            clear_console()
            -- Purchase a stamina potion
            if player.coins >= 25 then
                player.coins = player.coins - 25
                player.stamina_potions = player.stamina_potions + 1
                print("✅ Bought Stamina Potion! Total: " .. player.stamina_potions)
            else
                print("❌ Not enough coins! Need 25 coins.")
            end
            io.write("\nPress Enter to continue...")
            io.read()
        elseif choice == "3" then
            clear_console()
            -- Purchase an evasion potion
            if player.coins >= 25 then
                player.coins = player.coins - 25
                player.evasion_potions = player.evasion_potions + 1
                print("✅ Bought Evasion Potion! Total: " .. player.evasion_potions)
            else
                print("❌ Not enough coins! Need 25 coins.")
            end
            io.write("\nPress Enter to continue...")
            io.read()
        elseif choice_num and choice_num >= 4 and choice_num <= 3 + #shop_items then
            clear_console()
            -- Purchase equipment item
            local item_index = choice_num - 3
            local item = shop_items[item_index]
            if player.coins >= item.price then
                player.coins = player.coins - item.price
                player:add_item(item)
            else
                print("❌ Not enough coins! Need " .. item.price .. " coins.")
            end
            io.write("\nPress Enter to continue...")
            io.read()
        elseif choice_num == #shop_items + 4 then
            -- View inventory and stats
            clear_console()
            print("🎒 Your Inventory:\n")
            print("❤️   " .. player.health_potions .. " | ⚡  " .. player.stamina_potions .. " | 🧪  " .. player.evasion_potions)
            if #player.inventory == 0 then
                print("\n  Empty")
            else
                for i, item in ipairs(player.inventory) do
                    print("  " .. i .. ". " .. item.name .. " (" .. item.description .. ")")
                end
            end
            print("\n\n\n📊 Level " .. player.level .. " | Your Stats:\n")
            print("💪 Power: " .. player.power .. " | 🛡️  Defense: " .. player.defense .. " | 🎯 Accuracy: " .. player.accuracy)
            print("\n🌀 Dodge: " .. player.dodge .. " | ❤️  Max HP: " .. player.max_hp .. " | " .. "\n\n⚡ Max Stamina: " .. player.max_stamina .. " | ♻️  Stamina Regen: " .. player.stamina_regen)
            io.write("\n\n\nPress Enter to return to the shop...")
            io.read()
        elseif choice_num == #shop_items + 5 then
            -- Return to the arena
            player.inshop = false
            -- Clear the console and transition back to the arena
            clear_console()
            print("⚔️ Returning to the arena!")
            clear_for_transition()
        else
            clear_console()
            print("❌ Invalid choice!")
            io.write("\nPress Enter to continue...")
            io.read()
        end
    end
end

-- Arena function
function run_arena()
    local first_encounter = true
    while player.hp > 0 and player.inshop == false do
        if first_encounter then
            clear_for_transition()
            first_encounter = false
        end
        local monster = generate_monster()

        if monster.is_boss then
            print("\n🔥 BOSS APPEARS! 🔥")
            print("A " ..
                monster.name ..
                " (Level " .. monster.level .. ") emerges! (" .. monster.hp .. "/" .. monster.max_hp .. " HP)")
            print("Special: " .. monster.special_ability)
        else
            print("\nA Level " ..
                monster.level .. " " .. monster.name .. " appears! (" .. monster.hp .. "/" .. monster.max_hp .. " HP)")
            print("Special: " .. monster.special_ability)
        end
        print("")

        local last_action_result = ""
        while monster.hp > 0 and player.hp > 0 and player.inshop == false do
            -- Clear console and show last action result at top
            if last_action_result ~= "" then
                clear_console()
                print(last_action_result)
                print("------")
                last_action_result = ""
            end

            -- Display player and monster status.  Show the player's level
            -- alongside HP and current stamina.  Potion quantities are
            -- intentionally hidden to reduce clutter.
            print("You (Level " .. player.level .. "):❤️  " .. player.hp .. "/" .. player.max_hp ..
                " | Stamina: ⚡ " .. player.stamina .. "/" .. player.max_stamina ..
                " | " .. monster.name .. " (Lvl " .. monster.level .. "):❤️  " .. monster.hp .. "/" .. monster.max_hp .. "\n")

            -- Build a dynamic list of available actions based on the
            -- player's current inventory and unlocked abilities.  Only
            -- actions the player can perform appear in the menu.
            local actions = {}
            local option_idx = 1
            actions[option_idx] = "attack"
            print(option_idx .. ". 🗡️  Attack")
            option_idx = option_idx + 1

            actions[option_idx] = "strong_attack"
            print(option_idx .. ". 💪 Strong Attack (cost 3 ⚡, +5 Power, -3 Defense)")
            option_idx = option_idx + 1

            if player.heal_ability then
                actions[option_idx] = "heal"
                print(option_idx .. ". ✨ Heal (cost 5 ⚡)")
                option_idx = option_idx + 1
            end

            if player.health_potions > 0 then
                actions[option_idx] = "health_potion"
                print(option_idx .. ". ❤️  Use Health Potion")
                option_idx = option_idx + 1
            end

            if player.stamina_potions > 0 then
                actions[option_idx] = "stamina_potion"
                print(option_idx .. ". ⚡ Use Stamina Potion")
                option_idx = option_idx + 1
            end

            if player.evasion_potions > 0 then
                actions[option_idx] = "evasion_potion"
                print(option_idx .. ". 🧪 Use Evasion Potion")
                option_idx = option_idx + 1
            end

            actions[option_idx] = "flee"
            print(option_idx .. ". 🏪 Flee to the shop (take damage)")

            io.write("\nYour Action: ")
            local choice_input = io.read()
            local choice_num = tonumber(choice_input)
            local selected = actions[choice_num]
            -- Store action results instead of printing immediately
            local action_text = ""
            -- Flag used to skip stamina regeneration on strong attacks
            local skip_regen = false

            if selected == "attack" then
                local hit, dmg = player:attack(monster)
                if hit then
                    action_text = action_text .. "🗡️  You attacked " .. monster.name .. " and dealt " .. dmg .. " damage!\n"
                else
                    action_text = action_text .. "💨 " .. monster.name .. " dodged your attack!\n"
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
                        action_text = action_text .. "💪 You used Strong Attack on " .. monster.name .. " and dealt " .. dmg .. " damage!\n"
                    else
                        action_text = action_text .. "💨 " .. monster.name .. " dodged your strong attack!\n"
                    end
                else
                    action_text = action_text .. "❌ Not enough stamina for Strong Attack!\n"
                end
            elseif selected == "heal" then
                -- Heal ability uses stamina to restore HP
                if player.stamina >= 5 then
                    player.stamina = player.stamina - 5
                    local heal_amt = 20
                    player.hp = math.min(player.max_hp, player.hp + heal_amt)
                    action_text = action_text .. "✨ You focus and heal yourself for " .. heal_amt .. " HP!\n"
                else
                    action_text = action_text .. "❌ Not enough stamina to heal!\n"
                end
            elseif selected == "health_potion" then
                -- Use health potion
                player.health_potions = player.health_potions - 1
                local heal_amt = 20
                player.hp = math.min(player.max_hp, player.hp + heal_amt)
                action_text = action_text .. "❤️  You used a Health Potion and restored " .. heal_amt .. " HP!\n"
            elseif selected == "stamina_potion" then
                -- Use stamina potion
                player.stamina_potions = player.stamina_potions - 1
                local restore_amt = 5
                player.stamina = math.min(player.max_stamina, player.stamina + restore_amt)
                action_text = action_text .. "⚡ You used a Stamina Potion and restored " .. restore_amt .. " stamina!\n"
            elseif selected == "evasion_potion" then
                -- Use evasion potion if available
                if player:use_evasion_potion() then
                    clear_for_transition()
                    break
                end
            elseif selected == "flee" then
                -- Flee to the shop and take damage.  Store a message so the
                -- shop can display how much damage was taken.  Without
                -- this, the damage information was lost when transitioning
                -- screens.  We'll consume this message at the start of the
                -- next shop loop.
                player.inshop = true
                local flee_dmg = math.random(1, math.floor(monster.power / 2))
                player.hp = player.hp - flee_dmg
                action_text = "You retreat back to the shop!\nYou take " .. flee_dmg .. " damage while fleeing!"
                -- Save the flee message for the shop and clear the
                -- combat log.  Do not display it here because the next
                -- screen will handle it.
                pending_flee_message = action_text
                last_action_result = action_text
                clear_for_transition()
                break
            else
                action_text = action_text .. "Invalid choice. You lose your turn!\n"
            end

            -- Regenerate stamina at the end of the player's turn unless
            -- they performed a strong attack (cost remains 3 stamina)
            if not skip_regen then
                player.stamina = math.min(player.max_stamina, player.stamina + player.stamina_regen)
            end

            -- Monster special behaviors and attacks
            if monster.hp > 0 and not player.inshop then
                -- Slime regeneration
                if monster.name == "Slime" and math.random(1, 4) == 1 then
                    local regen = math.min(5, monster.max_hp - monster.hp)
                    monster.hp = monster.hp + regen
                    action_text = action_text .. "💚 " .. monster.name .. " regenerated " .. regen .. " HP!\n"
                end

                -- Monster attack with special modifiers
                local base_dmg = math.random(1, monster.power)
                local dmg = math.max(1, base_dmg - player.defense)

                -- Special monster behaviors
                if monster.name == "Skeleton" then
                    dmg = math.max(1, dmg - 2) -- Extra defense reduction
                elseif monster.name == "Bat" and math.random(1, 3) == 1 then
                    action_text = action_text .. "💨 " .. monster.name .. " dodged and counter-attacked!\n"
                    dmg = dmg + 2
                elseif monster.is_boss and math.random(1, 3) == 1 then
                    action_text = action_text .. "🔥 " .. monster.name .. " unleashes a devastating attack!\n"
                    dmg = math.floor(dmg * 1.5)
                end

                -- Apply player's dodge chance (capped so monsters always have a chance)
                local effective_dodge = player.dodge
                if effective_dodge > 80 then
                    effective_dodge = 80
                end
                local dodge_roll = math.random(1, 100)
                if dodge_roll <= effective_dodge then
                    action_text = action_text .. "💨 You dodged the attack!\n"
                    dmg = 0
                end

                if dmg > 0 then
                    action_text = action_text .. monster.name .. " hits you for " .. dmg .. "!"
                    player.hp = player.hp - dmg
                end
            end

            last_action_result = action_text
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
                for name, _ in pairs(monster_kills) do
                    if monster.name == name then
                        monster_kills[name] = monster_kills[name] + 1
                        if monster_kills[name] == 10 then
                            print("⚠️  You've killed 10 " .. name .. "s! A boss may appear soon...")
                        end
                        break
                    end
                end
            end

            -- Award coins and display the drop
            player.coins = player.coins + monster.coinDrop
            print("💰 You found " .. monster.coinDrop .. " coins! Total: " .. player.coins)

            -- Award experience and capture whether the player leveled up
            local leveled_up = player:gain_xp(monster.xpDrop)
            -- Show XP gain with an up arrow and the current level on the right
            print("⬆️  +" .. monster.xpDrop .. " XP  | Level " .. player.level)
            if leveled_up then
                print("🎉 Leveled up to level " .. player.level .. "! All stats increased by 1.")
            end

            -- If this was a boss, drop its unique item and increment kill count
            if monster.is_boss then
                local loot = boss_unique_items[monster.name]
                if loot then
                    boss_kill_counts[monster.name] = (boss_kill_counts[monster.name] or 0) + 1
                    print("🎁 The " .. monster.name .. " dropped " .. loot.name .. "!")
                    player:add_item(loot)
                    -- Grant special abilities if provided by the loot
                    if loot.grant_heal then
                        player.heal_ability = true
                        print("✨ You learned how to heal yourself!")
                    end
                    if loot.grant_lifesteal then
                        player.lifesteal_ability = true
                        print("🧛 You gained a lifesteal ability! Attacks will heal you.")
                    end
                end
            end

            -- Post‑combat choice: fight another or return to the shop.  Inform the player
            -- that choosing to continue fighting grants a bonus.  This tip
            -- encourages riskier play by rewarding consecutive battles.
            print("\n💡 Tip: Staying to fight another monster grants 20 bonus coins!")
            print("\n1. Fight another monster")
            print("2. Return to shop (free, no damage)")
            io.write("\nWhat would you like to do? ")
            local post_choice = io.read()
            if post_choice == "2" then
                player.inshop = true
                print("🏪 Returning to the shop!")
                clear_for_transition()
            else
                -- Reward the player for staying to fight
                player.coins = player.coins + 20
                print("💰 Bonus: You gained 20 coins for continuing to fight! Total: " .. player.coins)
                clear_for_transition()
            end
        elseif player.inshop == false and player.hp > 0 then
            print("☠️ You were defeated... Game over!")
        end
    end
end

-- Main Game Loop --
clear_console()
print("⚔️  Welcome to the Monster Arena! ⚔️\n")
print("🎯 Defeat monsters, collect coins, level up, and upgrade your equipment!")
print("💡 Tip: Kill 10 of the same monster type to face their boss!")
print("⚠️  Warning: Each monster type has their own special ability!\n")
print("Press Enter to begin...")
io.read()

while player.hp > 0 do
    if player.inshop then
        run_shop()
    else
        run_arena()
    end
end

print("\n💀 Game Over!")
print("Final Stats:")
print("  Level: " .. player.level)
print("  Coins Earned: " .. player.coins)
print("  Items Collected: " .. #player.inventory)
-- Display how many bosses were defeated and which ones.
local any_bosses = false
for name, count in pairs(boss_kill_counts) do
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
