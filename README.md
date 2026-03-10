# Discourse Points Mall Plugin

A comprehensive points mall plugin for Discourse that integrates with discourse-gamification.

## Features

### 1. Daily Check-in (签到)
- Users can check in daily to earn points
- Consecutive check-in streaks earn bonus points
- View check-in history, monthly calendar and ranking
- Makeup card support (up to 3 times per month, monthly reset)

### 2. Points Shop (积分商店)
- Exchange points for virtual or physical products
- Stock management for products
- Order tracking and history
- Built-in default makeup card product with tiered pricing (1000 / 3000 / 5000)

### 3. Points Ledger (积分明细)
- View points income and expense records
- Filter by income / expense / check-in / shop / community

## Installation

1. Add the plugin to your Discourse installation:
```bash
cd /var/discourse
git clone https://github.com/discourse/discourse-points-mall.git plugins/discourse-points-mall
```

2. Rebuild your Discourse container:
```bash
./launcher rebuild app
```

## Configuration

Enable the plugin in Admin > Settings > Plugins > discourse-points-mall

Available settings:
- `points_mall_enabled`: Enable/disable the plugin
- `points_mall_checkin_points`: Points awarded for daily check-in
- `points_mall_checkin_streak_bonus`: Bonus points for consecutive check-ins

## Requirements

- Discourse 2.7.0 or higher
- discourse-gamification plugin (for points system integration)

## Usage

After installation, users can access the Points Mall from the navigation bar. The mall includes:

- **Check-in**: Daily check-in page with streak tracking
- **Shop**: Browse and purchase products with points
- **Orders**: View order history
- **Ledger**: Track points income and spending details

## Database Schema

The plugin creates the following tables:
- `points_mall_products`: Product catalog
- `points_mall_orders`: User orders
- `points_mall_checkins`: Check-in records
- `points_mall_makeup_cards`: Monthly makeup card purchase/usage status

## License

MIT License
