# xmpauto

اسکریپت‌های آماده برای نصب و راه‌اندازی **XMPlus** و تانل **6to4/GRE6** روی سرورهای لینوکس (ایران و خارج).

---

## فهرست

- [معرفی](#معرفی)
- [ساختار ریپو](#ساختار-ریپو)
- [۱. XMPlus Setup](#۱-xmplus-setup)
- [۲. تانل 6to4 + GRE6](#۲-تانل-6to4--gre6)
- [عیب‌یابی](#عیب‌یابی)
- [خلاصه دستورات](#خلاصه-دستورات)
- [ریپو و لایسنس](#ریپو-و-لایسنس)

---

## معرفی

این ریپو دو اسکریپت اصلی دارد:

| اسکریپت | کاربرد |
|---------|--------|
| **setup.sh** | نصب XMPlus و ساخت خودکار کانفیگ با ApiHost، ApiKey و چند NodeID |
| **6to4-tunnel.sh** | ایجاد تانل 6to4 و GRE6 بین سرور ایران و خارج (بدون IPv6 واقعی) |

هر دو اسکریپت با یک دستور از GitHub قابل اجرا هستند و نیازی به کلون کردن ریپو نیست.

---

## ساختار ریپو

```
xmpauto/
├── README.md          # همین فایل
├── setup.sh            # اسکریپت نصب XMPlus و تولید کانفیگ
├── 6to4-tunnel.sh      # اسکریپت تانل 6to4 + GRE6
├── config.yml          # نمونه کانفیگ XMPlus (مرجع)
├── install.txt         # لینک نصب رسمی XMPlus
└── 6t4.md              # مرجع متنی آموزش 6to4
```

---

# ۱. XMPlus Setup

اسکریپت نصب XMPlus و تولید خودکار کانفیگ با ApiHost، ApiKey و NodeID های دلخواه.

## پیش‌نیاز

- سرور لینوکس: **CentOS 7+**، **Ubuntu 16+** یا **Debian 8+**
- دسترسی **root** یا **sudo**

## نصب و اجرا (یک‌خطی)

**یک نود:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1
```

**چند نود:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 3
```

**فقط کانفیگ (بدون نصب مجدد):**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/setup.sh) --apihost "https://www.xyz.com" --apikey "YOUR_KEY" --nodes 1 2 --config-only
```

## پارامترها

| پارامتر | توضیح |
|---------|-------|
| `--apihost` | آدرس API پنل (ثابت برای همه نودها) |
| `--apikey` | کلید API (ثابت برای همه نودها) |
| `--nodes` | لیست Node ID ها (برای هر کدوم یک بلوک کانفیگ ساخته میشه) |
| `--config-only` | فقط کانفیگ بساز، نصب نکن |

## خروجی

- نصب XMPlus در `/usr/local/XMPlus/`
- کانفیگ در `/etc/XMPlus/config.yml`
- سرویس systemd: **XMPlus**

## دستورات مدیریت XMPlus (بعد از نصب)

| دستور | کار |
|-------|-----|
| `XMPlus` | نمایش منو |
| `XMPlus start` | شروع سرویس |
| `XMPlus stop` | توقف سرویس |
| `XMPlus restart` | ریستارت سرویس |
| `XMPlus status` | وضعیت سرویس |
| `XMPlus log` | مشاهده لاگ |
| `XMPlus config` | نمایش محتوای کانفیگ |
| `XMPlus update` | آپدیت XMPlus |

---

# ۲. تانل 6to4 + GRE6

اسکریپت ایجاد تانل **6to4** و **GRE6** بین سرور ایران و سرور خارج، **بدون نیاز به IPv6 واقعی**. پشتیبانی از **چند سرور ایران** به **یک سرور خارج**.

## پیش‌نیاز

- دو سرور: یکی در ایران، یکی خارج
- آیپی **IPv4 پابلیک** هر دو سرور
- دسترسی **root** یا **sudo**

## آموزش گام‌به‌گام

### سناریو: ۲ سرور ایران + ۱ سرور خارج

فرض کن:
- **سرور ایران ۱:** آیپی `1.1.1.1`
- **سرور ایران ۲:** آیپی `2.2.2.2`
- **سرور خارج:** آیپی `9.9.9.9`

---

### گام ۱: سرور ایران ۱

به سرور اول ایران وصل شو و اجرا کن:

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) iran --kharej-ip 9.9.9.9 --iran-ip 1.1.1.1 --tunnel-id 1
```

- `--kharej-ip`: آیپی سرور خارج  
- `--iran-ip`: آیپی همین سرور ایران  
- `--tunnel-id`: شماره تانل (برای سرور اول = 1)

---

### گام ۲: سرور ایران ۲

به سرور دوم ایران وصل شو و اجرا کن:

```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) iran --kharej-ip 9.9.9.9 --iran-ip 2.2.2.2 --tunnel-id 2
```

همین پارامترها، فقط `--iran-ip` و `--tunnel-id` عوض میشه.

---

### گام ۳: سرور خارج (برای هر سرور ایران یکبار)

به سرور خارج وصل شو. برای **هر** سرور ایران یک دستور جدا اجرا کن:

**تانل مربوط به سرور ایران ۱:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) kharej --iran-ip 1.1.1.1 --kharej-ip 9.9.9.9 --tunnel-id 1
```

**تانل مربوط به سرور ایران ۲:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) kharej --iran-ip 2.2.2.2 --kharej-ip 9.9.9.9 --tunnel-id 2
```

---

### گام ۴: تست تانل

**از سرور ایران ۱:**
```bash
ping6 fde8:b030:25cf::de02
ping 172.20.20.2
```

**از سرور ایران ۲:**
```bash
ping6 fde8:b030:25cf::de04
ping 172.20.21.2
```

**از سرور خارج:**
```bash
ping6 fde8:b030:25cf::de01
ping 172.20.20.1

ping6 fde8:b030:25cf::de03
ping 172.20.21.1
```

اگر پینگ جواب داد، تانل درست برقرار شده.

---

## آدرس‌های تولیدشده (پیش‌فرض)

| تانل | IPv6 ایران | IPv6 خارج | IPv4 لوکال ایران | IPv4 لوکال خارج |
|------|------------|-----------|-----------------|-----------------|
| 1 | fde8:b030:25cf::de01 | fde8:b030:25cf::de02 | 172.20.20.1 | 172.20.20.2 |
| 2 | fde8:b030:25cf::de03 | fde8:b030:25cf::de04 | 172.20.21.1 | 172.20.21.2 |
| 3 | fde8:b030:25cf::de05 | fde8:b030:25cf::de06 | 172.20.22.1 | 172.20.22.2 |

## پارامتر اختیاری: تغییر پایه IPv6

اگر بخوای از رنج IPv6 دیگری استفاده کنی:

```bash
sudo bash <(curl -Ls .../6to4-tunnel.sh) iran --kharej-ip 9.9.9.9 --iran-ip 1.1.1.1 --tunnel-id 1 --ipv6-base "fde8:1234:abcd"
```

آدرس‌ها به صورت `fde8:1234:abcd::de01` و `fde8:1234:abcd::de02` و ... ساخته میشن.

## دستورات دیگر

**نمایش وضعیت تانل‌ها:**
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) status
```

**حذف تانل:**

روی سرور ایران:
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) remove --tunnel-id 1 --role iran
```

روی سرور خارج:
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) remove --tunnel-id 1 --role kharej
```

**راهنمای داخل اسکریپت:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/hosseinpv1379/xmpauto/main/6to4-tunnel.sh) --help
```

## ماندگاری بعد از ریبوت

تنظیمات تانل در **`/etc/rc.local`** ذخیره میشه و بعد از ریستارت سرور خودکار اجرا میشه. برای غیرفعال کردن، از دستور **remove** استفاده کن یا محتوای مربوط به تانل را از `/etc/rc.local` حذف کن.

---

## عیب‌یابی

### XMPlus

| مشکل | راه‌حل |
|------|--------|
| نصب نشد / خطای دانلود | اتصال به اینترنت و دسترسی به GitHub را چک کن؛ در صورت فیلتر از پراکسی استفاده کن. |
| سرویس استارت نمیشه | `XMPlus log` را ببین؛ مسیر کانفیگ `/etc/XMPlus/config.yml` و دسترسی فایل را چک کن. |
| کانفیگ عوض نمیشه | با `--config-only` دوباره کانفیگ بساز؛ بعد `XMPlus restart` بزن. |

### تانل 6to4

| مشکل | راه‌حل |
|------|--------|
| پینگ جواب نمیده | ترتیب اجرا را رعایت کن: اول هر دو طرف تانل 6to4 و GRE6 را بزن، بعد تست کن. |
| بعد از ریبوت تانل نیست | وجود و اجرایی بودن `/etc/rc.local` را چک کن؛ لاگ بوت را ببین. |
| خطای «File exists» یا اینترفیس تکراری | قبلاً تانل با همین `tunnel-id` ساخته شده؛ اول با `remove` حذف کن، بعد دوباره اجرا کن. |
| iptables خطا میده | روی سرور ایران، در صورت تداخل قوانین، قبل از اجرای مجدد اسکریپت قوانین NAT را با `iptables -t nat -F` خالی نکن مگر اینکه بدونی چی میکنی؛ ترجیحاً فقط از دستور **remove** استفاده کن. |

---

## خلاصه دستورات

| کار | دستور |
|-----|--------|
| نصب XMPlus (یک نود) | `sudo bash <(curl -Ls .../setup.sh) --apihost "URL" --apikey "KEY" --nodes 1` |
| نصب XMPlus (چند نود) | `... --nodes 1 2 3` |
| فقط کانفیگ XMPlus | `... --config-only --nodes 1 2` |
| تانل روی سرور ایران | `sudo bash <(curl -Ls .../6to4-tunnel.sh) iran --kharej-ip X --iran-ip Y --tunnel-id N` |
| تانل روی سرور خارج | `sudo bash <(curl -Ls .../6to4-tunnel.sh) kharej --iran-ip Y --kharej-ip X --tunnel-id N` |
| وضعیت تانل‌ها | `sudo bash <(curl -Ls .../6to4-tunnel.sh) status` |
| حذف تانل | `sudo bash <(curl -Ls .../6to4-tunnel.sh) remove --tunnel-id N --role iran` یا `kharej` |

**آدرس ریپو:**  
https://github.com/hosseinpv1379/xmpauto

---

## ریپو و لایسنس

- **ریپو:** [github.com/hosseinpv1379/xmpauto](https://github.com/hosseinpv1379/xmpauto)
- این اسکریپت‌ها فقط برای **یادگیری و استفاده شخصی** هستند. استفاده در محیط‌های حساس بدون تست و مسئولیت خودت توصیه نمیشه.
- XMPlus پروژه جداگانه‌ای است؛ برای نصب از اسکریپت رسمی آن‌ها استفاده می‌شود و لایسنس و قوانین مربوط به خود XMPlus است.
