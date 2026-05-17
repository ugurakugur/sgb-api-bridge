# Entegrasyon: Microsoft Sentinel

> **Hedef:** SGB TAXII koleksiyonları Sentinel Threat Intelligence
> blade'ine ingest edilsin; analytics rule'lar bu TI'ı kullanarak alarm
> üretebilsin.

**Tüketilen servis:** `https://sgb-taxii.bilsec.tr/taxii2/` (anonim, TAXII 2.1)

## BG Rehberi karşılığı

| Madde | Madde adı | Bu entegrasyon nasıl karşılar? |
|-------|-----------|--------------------------------|
| **3.1.8.6** | Merkezi Kayıt Yönetimi | Sentinel = bulut SIEM. |
| **3.1.8.7** ⭐ | Kayıt Analizi Araçları (SIEM) | KQL analytics rule'lar = korelasyon. |
| **3.1.10.4** ⭐ | Siber Tehdit Bildirimlerinin Yönetilmesi | SGB TAXII → Sentinel TI blade. |
| **4.3** | Bulut Bilişim Güvenliği | Bulut SIEM kullanımı bu bölüm kapsamındadır. |
| **3.1.11.1** | Sızma Testleri ve Güvenlik Denetimleri | Sentinel "indicator backsearch" pattern'i sürekli geriye dönük tarama yapar. |

## Ön koşullar

- Azure Sentinel (Microsoft Sentinel)
- Log Analytics Workspace + Sentinel etkin
- "Microsoft Sentinel Contributor" rolü
- Workspace bölgesinden `sgb-taxii.bilsec.tr:443` erişimi (default Azure
  egress'inde sorun olmaz; özel firewall varsa allowlist'e ekleyin)

## Kurulum — Threat Intelligence (TAXII) data connector

Sentinel'in built-in **Threat Intelligence - TAXII** data connector'ı
TAXII 2.0/2.1 koleksiyonlarını destekler — Logic App, App registration,
Graph API gerekmez.

**Sentinel → Data connectors → "Threat Intelligence - TAXII" → Open
connector page → Configure**

| Alan | Değer (örnek: phishing) |
|------|-------------------------|
| Friendly name | `SGB-Phishing` |
| API root URL | `https://sgb-taxii.bilsec.tr/api/` |
| Collection ID | `sgb-phishing` |
| Username | (boş) |
| Password | (boş) |
| Import indicators | Last 90 days (veya All) |
| Polling frequency | Hourly |

Aynı işlemi her UC için tekrarlayın (8 koleksiyon → 8 connector):

| Connector | Collection ID | UC prefix |
|-----------|---------------|-----------|
| `SGB-Phishing` | `sgb-phishing` | UC-PH-* |
| `SGB-Botnet-CC` | `sgb-botnet-cc` | UC-BC-* |
| `SGB-APT-CC` | `sgb-apt-cc` | UC-AC-* |
| `SGB-Exploit-Kit` | `sgb-exploit-kit` | UC-EK-* |
| `SGB-Malware-Download` | `sgb-malware-download` | UC-MF-* |
| `SGB-Mining` | `sgb-mining` | UC-MM-* |
| `SGB-Mobile-CC` | `sgb-mobile-cc` | UC-MC-* |
| `SGB-Other` | `sgb-other` | UC-OT-* |

## Doğrulama

Sentinel UI > **Threat Intelligence** → filter `Source = "SGB-Phishing"`
(veya diğerleri). Indicator'lar listelenir; her birinin properties'inde
`x_sgb_*` custom field'larımız (connectiontype, criticality, source)
korunmuş olur.

KQL:

```kusto
ThreatIntelligenceIndicator
| where SourceSystem startswith "SGB-"
| summarize count() by SourceSystem, ThreatType, ConfidenceScore
```

## Analytics rule önerileri

**Built-in template'lar (otomatik aktivasyon — ekstra iş yok):**

- "TI map IP entity to *" rule'ları — tüm log table'larına karşı SGB
  indicator'larını otomatik tarar
- "TI map Domain entity to *", "TI map URL entity to *"

Custom rule (UC-BC-001 muadili):

```kusto
let sgb_ti = ThreatIntelligenceIndicator
    | where SourceSystem == "SGB-Botnet-CC"
    | where ConfidenceScore >= 60;
sgb_ti
| join kind=inner (CommonSecurityLog | where TimeGenerated > ago(1h))
    on $left.NetworkIP == $right.DestinationIP
| project TimeGenerated, SourceIP, DestinationIP, ThreatType,
          ConfidenceScore, Description
```

## Lifecycle / expiration

Sentinel TAXII connector indicator'ları kendi yaşam döngüsünü yönetir;
manuel `expirationDateTime` yazmaya gerek yok. SGB feed'inden silinen
indicator'lar artık TAXII envelope'unda dönmediği için sonraki polling
turlarında "absent" olarak işlenir.

## Indicator backsearch (BG 3.1.11.1 ile bağlantı)

Sentinel her yeni indicator için **geçmiş 14 güne kadar geriye dönük**
log tarar (Threat Intelligence built-in rule'lar default davranış). BG
**3.1.11.1**'in "düzenli sızma testleri / güvenlik denetimleri"
beklentisinin **sürekli** versiyonudur: SGB feed'inde yeni indicator
çıktığında geçmişteki tüm log'lar otomatik taranır → "bunu daha önce hiç
görmüşmüyüz?" sorusunun cevabı sürekli güncel.

## Troubleshooting

| Belirti | Sebep | Çözüm |
|---------|-------|-------|
| Connector "Disconnected" | Network egress | Workspace bölgesinden `sgb-taxii.bilsec.tr` resolve + 443 reach |
| Indicator yok ama connector "Connected" | İlk polling henüz tamamlanmadı | 1-2 saat bekle; ilk koleksiyon büyükse (PH ~50K) ingest sürer |
| 401/403 | (olmamalı, anonim servis) | Username/Password alanlarını boş bırakın |
| Duplicate indicators | Aynı collection iki connector'da | Tek tanım kalsın |
| ConfidenceScore 0 | STIX `confidence` field okunmadı | Sentinel TAXII connector v2'ye geçtiğinden emin olun (eski v1 confidence map etmiyordu) |
