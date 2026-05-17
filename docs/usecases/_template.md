# UC-XX-NNN — <Kısa Türkçe Başlık>

> **TL;DR:** 1-2 cümlelik özet. Bu use case neyi yakalar, kim için değerli?

## Bu use case nedir? (Basit anlatım)

(2-4 paragraf, teknik olmayan da anlasın. Hangi senaryo, hangi log
kaynağında, hangi SGB feed alanı, nasıl korelasyon.)

## Senaryo (Hikâye)

(Zaman çizelgeli somut bir örnek olay. 4-6 satır. Saatler kullan.)

## BG Rehberi karşılığı

| Madde | Madde adı | Bu UC ne sağlar? |
|-------|-----------|-------------------|
| **3.x.y.z** | ... | ... |
| **3.1.10.4** | Siber Tehdit Bildirimlerinin Yönetilmesi | SGB feed kullanımı (her UC ortak). |
| **3.1.8.7** | Kayıt Analizi Araçları (SIEM) | SIEM korelasyon (her UC ortak). |

## Teknik özet

| Alan | Değer |
|------|-------|
| ID | UC-XX-NNN |
| MITRE ATT&CK | TAxxxx / Txxxx |
| Connectiontype | PH/BC/AC/EK/MF/MM/MC/OT/XX |
| Severity (base) | 1-10 (severity-matrix.md formülü) |
| Veri kaynakları | (DNS, Proxy, Firewall, EDR, Email, MDM, ...) |
| TAXII koleksiyonu | `sgb-<phishing\|botnet-cc\|apt-cc\|exploit-kit\|malware-download\|mining\|mobile-cc\|other>` |
| Response | PB-XX-NNN (varsa) |

## Tespit mantığı (vendor-bağımsız)

```text
when <event geldi>
  AND <SGB lookup eşleşti>
  AND <ek filter>
then <aksiyon>
```

## SIEM uygulaması

İlgili TAXII koleksiyonunu SIEM'inize feed olarak ekleyin
(bkz. [integrations/](../integrations/)). Tüm modern ürünlerde indicator
otomatik olarak TI store'a yazılır; rule "indicator match" property'si
ile yazılır — vendor-spesifik reference set/map veya lookup gerekmez.

Örnek (QRadar):

```
when any of these properties matches a TAXII Feed indicator
     from feed SGB-<Collection>
  AND <ek filter>
```

Örnek (Splunk ES):

```spl
| `threatintel_lookup`
| search threat_group="SGB-<Collection>" AND ...
```

## Yanlış pozitif (False Positive) notları

- Bilinen FP kaynakları + suppress/exception önerileri
- `source=IH` için güvenirlik düşürme stratejisi

## Olay müdahale (Response playbook)

**Otomatik adımlar:**
1. ...

**Manuel triage adımları:**
1. ...

**SGB raporlama etkisi (3.1.10.5):** (varsa)
