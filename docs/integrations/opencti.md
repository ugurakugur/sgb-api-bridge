# Entegrasyon: OpenCTI

> **Hedef:** SGB TAXII koleksiyonları OpenCTI'a native TAXII connector
> üzerinden otomatik ingest edilsin.

**Tüketilen servis:** `https://sgb-taxii.bilsec.tr/taxii2/` (anonim, TAXII 2.1)

## BG Rehberi karşılığı

| Madde | Madde adı | Bu entegrasyon nasıl karşılar? |
|-------|-----------|--------------------------------|
| **3.1.10.4** ⭐ | Siber Tehdit Bildirimlerinin Yönetilmesi | OpenCTI = TI hub; SGB TAXII feed otomatik akıyor. |
| **3.1.8.7** | Kayıt Analizi Araçları (SIEM) | OpenCTI'dan SIEM'e push connector'ları mevcut. |
| **3.1.10.5** | Olay Raporlarının Standardize Edilmesi | OpenCTI'ın "Report" entity'leri standart format. |
| **3.1.10.8** | Olay Puanlama / Önceliklendirme | Confidence + criticality alanları puanlamayı destekler. |

OpenCTI MISP'e alternatif (graph-tabanlı, STIX-native) bir TI platformudur.
Görselleştirme, entity ilişkileri ve playbook otomasyonu için tercih
edilir.

## Ön koşullar

- OpenCTI 5.10+ veya 6.x
- Connector deploy yetkisi (docker-compose veya k8s)
- OpenCTI API token
- Connector host'undan `sgb-taxii.bilsec.tr:443` erişimi

## Kurulum — TAXII 2.1 connector

OpenCTI'ın resmi `external-import-taxii` connector'u tek tanımla tüm
SGB koleksiyonlarını çeker.

```yaml
# docker-compose.override.yml
services:
  connector-sgb-taxii:
    image: opencti/connector-external-import-taxii:6.4.0
    environment:
      - OPENCTI_URL=http://opencti:8080
      - OPENCTI_TOKEN=${OPENCTI_TOKEN}
      - CONNECTOR_ID=sgb-taxii
      - CONNECTOR_TYPE=EXTERNAL_IMPORT
      - CONNECTOR_NAME=SGB TAXII 2.1
      - CONNECTOR_SCOPE=stix2
      - CONNECTOR_CONFIDENCE_LEVEL=70
      - CONNECTOR_LOG_LEVEL=info
      - TAXII2_DISCOVERY_URL=https://sgb-taxii.bilsec.tr/taxii2/
      - TAXII2_USE_TAXII_FOR_HEALTH_CHECK=true
      - TAXII2_COLLECTIONS=sgb-phishing,sgb-botnet-cc,sgb-apt-cc,sgb-exploit-kit,sgb-malware-download,sgb-mining,sgb-mobile-cc,sgb-other
      - TAXII2_INITIAL_HISTORY=86400      # ilk pull icin geriye 24 saat
      - TAXII2_INTERVAL=3600              # saatlik
    restart: always
```

Başlat:

```bash
cd opencti-deployment
docker-compose pull connector-sgb-taxii
docker-compose up -d connector-sgb-taxii
docker-compose logs -f connector-sgb-taxii
```

## Doğrula

1. OpenCTI → **Data → Ingestion → Connectors** → `SGB TAXII 2.1` status "Running"
2. **Observations → Indicators** → SGB indicator'ları (label filter:
   `sgb`, `sgb:ct:PH`, …)
3. Identity panelinde: "Siber Güvenlik Başkanlığı (SGB)" otomatik oluşur
   (STIX bundle'larında identity object hep aynı UUID ile gelir)

## Label / tag stratejisi

OpenCTI 6.x'te connector level'da global label yetersiz; iki ek seçenek:

1. **Stream filter** — `Settings → Customization → Streams` ile SGB
   indicator'larına otomatik `sgb:ct:<CT>` label uygula (`x_sgb_connectiontype`
   STIX custom property'sinden)
2. **Playbook** — `Data → Processing → Playbooks` ile "TAXII import"
   trigger'ına label-injection adımı ekle

## Confidence level

STIX indicator'larımızda `confidence` alanı var (source bazlı: US/SB=85,
IH=40). OpenCTI bunu otomatik kullanır; UI'da Indicator detayında görülür.

`CONNECTOR_CONFIDENCE_LEVEL` env'i connector-wide override sunar (tüm
SGB indicator'larına minimum 70 ata, gibi).

## Lifecycle yönetimi

SGB feed'inden silinen indicator'lar TAXII envelope'unda artık dönmez
(STIX `revoked` flag'i kullanılmıyor). OpenCTI lifecycle:

- Indicator'ın `valid_until` field'ı STIX'te set değilse OpenCTI default
  yaşam süresi uygular (90 gün, ayarlanabilir)
- **Playbook ile otomatik:** "Indicator not seen in 30 days → set
  revoked=true" pattern'i kurun
- Tam senkronizasyon için: aylık manuel "compare TAXII feed vs OpenCTI
  state" raporu çıkarın (custom script)

## BG raporlama için kullanım

OpenCTI üzerinden SGB indicator'larını **Threat actor**, **Campaign**,
**Malware**, **Attack pattern** entity'leri ile ilişkilendirebilirsiniz.
BG **3.1.10.5** kapsamında üretilecek siber olay raporları için zengin
bağlamsal bilgi sağlar:

- Hangi indicator hangi MITRE ATT&CK tekniğine bağlı
- Hangi tehdit aktörünün TTP'sine uyuyor
- Olay zaman çizelgesi otomatik üretilir

## Troubleshooting

| Belirti | Sebep | Çözüm |
|---------|-------|-------|
| Connector "Running" ama indicator yok | TAXII collection ID yanlış | `TAXII2_COLLECTIONS` listesini `setup-taxii.md` ile karşılaştır |
| Identity her sync'te yeniden oluşturuluyor | Dedup ayarı kapalı | OpenCTI `application.properties`'te `dedup_keys` |
| Tüm indicator confidence=50 | Connector confidence override aktif | `CONNECTOR_CONFIDENCE_LEVEL` env'i kaldır veya STIX `confidence`'ı koru |
| 401/403 | (olmamalı, anonim servis) | TAXII URL'i doğru mu? Connector log'una bak |
| Slow ingest | İlk koleksiyon büyük (PH ~50K) | `TAXII2_INITIAL_HISTORY` küçült veya batch ingest ayarla |
