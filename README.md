# XMPlus Setup

اسکریپت نصب XMPlus و تولید خودکار کانفیگ با ApiHost، ApiKey و NodeID های دلخواه.

## نصب و اجرا (یک‌خطی)

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1
```

### چند نود

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 3
```

### فقط کانفیگ (بدون نصب مجدد)

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 --config-only
```

## پارامترها

| پارامتر | توضیح |
|---------|-------|
| `--apihost` | آدرس API (ثابت) |
| `--apikey` | کلید API (ثابت) |
| `--nodes` | لیست Node ID ها (برای هر کدوم یک بلوک کپی میشه) |
| `--config-only` | فقط کانفیگ بساز، نصب نکن |
