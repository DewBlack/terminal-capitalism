# AGENTS.md

## Project

This project is a Godot 4 game called **Terminal Capitalism**.

It is an absurd stock market roguelike where the player buys and sells stocks to survive a 30-day run.

The game uses:
- Godot 4
- GDScript
- Simple UI
- Data-driven content through JSON
- No runtime generative AI
- No external assets for the MVP

## Core Loop

The main gameplay loop is:

1. Read market news.
2. Analyze affected tags.
3. Buy or sell stocks.
4. End the day.
5. Watch prices change.
6. Pay weekly expenses.
7. Survive until day 30.

## Main Design Rules

- The market can be absurd, but it must not feel random.
- Price changes should be explainable through tags.
- Every important price movement should have readable reasons.
- News affects companies through tag matching.
- Companies have stats that modify price impact:
  - volatility
  - reputation
  - hype
  - legal_risk
  - debt
  - absurdity
- Meme companies should be more volatile.
- Stable companies should move less.
- High legal risk companies should suffer more from scandals and regulation.
- High hype companies should rise harder on good news and fall harder on bad news.

## MVP Scope

The MVP must include:

- Main menu
- New run
- Market screen
- Company table
- News panel
- Company details panel
- Buy shares
- Sell shares
- End day
- Daily news
- Weekly expenses
- Weekly temporary upgrades
- Company creation
- Company bankruptcy
- Company mergers
- Victory after surviving 30 days
- Defeat by debt or negative net worth

## Do Not Add Yet

Do not add these systems unless explicitly requested:

- Steam integration
- Monetization
- Online features
- Runtime AI generation
- Advanced save system
- Localization system
- Final art
- Final audio
- DLC implementation
- Complex animations
- Complex charts
- Multiplayer

## Architecture Rules

Keep simulation logic separate from UI.

Do not put market logic inside UI scripts.

Use managers for global systems:

- GameManager
- RunManager
- MarketManager
- NewsManager
- PlayerPortfolio
- UpgradeManager
- ContentPackLoader

Use data classes or lightweight scripts for:

- Company
- NewsEvent
- RunUpgrade
- PriceMovement
- MarketEffect

Prefer small functions.

Avoid circular dependencies.

Use signals when UI needs to react to simulation changes.

Keep scripts readable and commented.

## Folder Structure

Use this structure:

```text
res://
  scenes/
    main/
    menu/
    game/
    ui/

  scripts/
    core/
    run/
    player/
    market/
    news/
    ui/
    utils/

  data/
    base/
    packs/
      example_pack/

  art/
    placeholder/

  audio/
    placeholder/