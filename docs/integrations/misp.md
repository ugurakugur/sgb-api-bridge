# Entegrasyon: MISP

> **Hedef:** SGB TAXII koleksiyonları MISP'e otomatik ingest edilsin; her
> saatlik polling'de taze kal.

**Tüketilen servis:** `https://sgb-taxii.bilsec.tr/taxii2/` (anonim, TAXII 2.1)

## BG Rehberi karşılığı

| Madde | Madde adı | Bu entegrasyon nasıl karşılar? |
|-------|-----------|--------------------------------|
| **3.1.10.4** ⭐ | Siber Tehdit Bildirimlerinin Yönetilmesi | MISP = TI yönetim hub'ı; SGB TAXII feed bu hub'a otomatik akıyor. |
| **3.1.8.7** | Kayıt Analizi Araçları (SIEM) | MISP indicator'ları SIEM'e push edilebilir. |
| **3.1.5.1** | Zararlı Yazılımdan Korunma + Merkezi Yönetim | MISP merkezi IoC veri tabanıdır. |

MISP genelde **SIEM beslemeyen, başka TI kaynaklarıyla korelasyon kuran**
bir hub olarak konumlandırılır. SGB feed'i + diğer TI kaynakları + iç
research = zenginleştirilmiş gözlem havuzu.

## Ön koşullar

- MISP **2.4.160+** (native TAXII 2.1 client)
- Admin yetkisi (TAXII server + sync)
- MISP host'undan `sgb-taxii.bilsec.tr:443` erişimi

## Kurulum — TAXII 2.1 server ekle

**Sync Actions → List TAXII Servers → Add**

| Alan | Değer (örnek: phishing) |
|------|-------------------------|
| Name | `SGB TAXII 2.1 — Phishing` |
| Base URL | `https://sgb-taxii.bilsec.tr/taxii2/` |
| Version | 2.1 |
| Authentication | None |
| Collection | `sgb-phishing` |
| Default tag | `tlp:white`, `source:sgb`, `sgb:ct:PH` |
| Pull interval | 1 saat |
| Distribution | Your organisation only (veya All communities — TLP:WHITE) |

8 koleksiyon için tekrarlayın. Alternatif olarak tek server tanımıyla
birden fazla koleksiyon abone olma desteği MISP sürümüne göre değişir.

CLI / API eşdeğeri:

```bash
sudo -u www-data /var/www/MISP/app/Console/cake Server addTaxii \
  --base_url https://sgb-taxii.bilsec.tr/taxii2/ \
  --version 2.1 \
  --collection sgb-phishing \
  --name "SGB Phishing"
```

## İlk pull'u tetikle

```bash
# UI: Sync Actions → List TAXII Servers → [SGB ...] → Pull
# CLI:
sudo -u www-data /var/www/MISP/app/Console/cake Server pullTaxii 1
```

## Doğrula

UI: **Events → List Events** → `source:sgb` tag ile filtrele. Her koleksiyon
için bir event grubu oluşur; indicator'lar attribute olarak listelenir
(domain, ip-dst, url tipinde).

## Otomatik refresh

MISP scheduler: **Administration → Scheduled Tasks → pull_taxii**

- Default 24 saat; **1 saate çekin** (SGB delta cadence'ine eşle)
- Worker: `BackgroundJobs` queue çalışıyor olmalı (`/var/www/MISP/app/Console/cake CleanCache`'den önce kontrol)

## Tag stratejisi

| Tag | Anlam | Otomatik |
|------|-------|----------|
| `tlp:white` | Public veri | Default tag |
| `source:sgb` | Tüm SGB indicator'ları | Default tag |
| `sgb:ct:PH` / `sgb:ct:BC` … | Connectiontype (koleksiyon bazlı) | Default tag (her server için ayrı) |
| `sgb:src:US` / `sgb:src:IH` … | Kaynak güvenilirliği | Custom enrichment script (opsiyonel — `x_sgb_source` field'ından) |

`x_sgb_*` STIX custom property'leri MISP tarafında `Object → Stix-2`
attribute olarak korunur; query'lerle erişilebilir.

## Sync to other MISP instances

SGB feed'ini diğer MISP'lere yayınlıyorsanız:

- **Distribution: This community** (yalnız kendi sync grubuna)
- Veya **All communities** (TLP:WHITE ise uygun)

## BG raporlama için kullanım

MISP'i SGB feed'i + iç research + diğer TI kaynaklarının birleştiği yer
yaparsanız, BG Rehberi **3.1.10.5** kapsamında üretmeniz gereken siber
olay raporlarına aşağıdaki bilgileri kolayca dahil edebilirsiniz:

- Indicator hangi kampanyaya / hangi APT grubuna bağlı (MISP galaxy)
- Aynı indicator başka kuruluşlarda görüldü mü (MISP sharing communities)
- IoC yaşam döngüsü (ilk görülme, son görülme)

## Air-gapped alternatif (MISP TAXII'ye çıkamıyor)

Bu durumda kendi TAXII servisinizi self-host edin:
[setup-docker.md](../setup-docker.md) → MISP iç ağdaki Docker host'a
bağlanır. SGB API'sine ulaşım için Docker host'a outbound HTTPS yeter
(MISP'in kendisi internet'e çıkmaz).

## Troubleshooting

| Belirti | Sebep | Çözüm |
|---------|-------|-------|
| Pull hata: invalid STIX | MISP < 2.4.160 | MISP upgrade — eski sürümlerin TAXII 2.1 desteği eksik |
| Event yok ama TAXII server "Connected" | Worker çalışmıyor | `BackgroundJobs` workers status |
| Indicator yok, sadece identity event'inde | STIX parser bypass | `/var/www/MISP/app/tmp/logs/error.log` |
| Duplicate event her pull'da | Pull dedup off | Server config'te "Caching enabled" + "Lookup visible" |
| 401/403 | (olmamalı, anonim servis) | Username/Password boş; Base URL trailing slash `/taxii2/` |
