# Docker kurulumu

Tek konteyner ile SGB API Bridge'i ayağa kaldır. İçinde nginx + sync loop birlikte çalışır.

## Önkoşullar

- Docker 20.10+ (compose v2 ile)
- Host'tan SGB API'sine (`https://siberguvenlik.gov.tr`) erişim. Proxy varsa Docker daemon ayarlarında `HTTPS_PROXY` set edilmeli.
- ~1 GB disk (state + feed dosyaları için).

## Hızlı başlangıç

```bash
docker run -d \
  --name sgb-api-bridge \
  -p 8080:80 \
  -v sgb-api-bridge-data:/data \
  --restart unless-stopped \
  ghcr.io/bilsectr/sgb-api-bridge:latest
```

Konteyner ayağa kalkar ve **hemen kullanılabilir**:

- İmaj, geçmiş feed verisini (`docs/*-list.txt`) ve `state/seen_ids.json`'u **gömülü taşır**. Boş bir volume'a ilk açılışta bu seed verisi `/data`'ya kopyalanır.
- HTTP 8080 portu anında dolu feed'leri sunar — full sync beklemeye gerek yok.
- Internal loop her saat **delta sync** çalıştırır, seed verisindeki `max_id`'den devam eder.
- `docker logs -f sgb-api-bridge` ile izleyebilirsin.

> İmaj her hafta yeniden build edilir; gömülü seed verisi en fazla ~1 hafta bayattır, ilk delta bu boşluğu kapatır. **Full sync gerekmez.**

## docker-compose ile

```bash
git clone https://github.com/bilsectr/sgb-api-bridge.git
cd sgb-api-bridge
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml logs -f
```

## Feed URL'leri

```
http://<host-ip>:8080/domain-list.txt
http://<host-ip>:8080/ip-list.txt
http://<host-ip>:8080/url-list.txt
http://<host-ip>:8080/ip6-list.txt
http://<host-ip>:8080/ip6net-list.txt
http://<host-ip>:8080/stats.json
```

FortiGate konfigürasyonu:

```
config system external-resource
    edit "SGB-Domain"
        set type domain
        set resource "http://10.0.0.5:8080/domain-list.txt"
        set refresh-rate 60
    next
    edit "SGB-IP"
        set type address
        set resource "http://10.0.0.5:8080/ip-list.txt"
        set refresh-rate 60
    next
end
```

## HTTPS önerisi

Konteyner kendisi sadece HTTP konuşur. Üretimde **reverse proxy** ile HTTPS sonlandırması yap:

- Traefik, Caddy, nginx-proxy ile otomatik Let's Encrypt
- Veya kurumsal CA ile statik sertifika

Caddy ile en kısa örnek:

```caddyfile
sgb-feed.kurum.local {
    reverse_proxy localhost:8080
}
```

## Manuel komutlar

```bash
# Tek seferlik delta (debug icin)
docker exec sgb-api-bridge /entrypoint.sh sync-once delta

# Health check
docker exec sgb-api-bridge /entrypoint.sh healthcheck

# Container icinde shell
docker exec -it sgb-api-bridge sh

# Sifirdan tam re-sync (NADIR — seed verisi cok bayatladiysa, ~10-15+ saat):
docker run --rm -v sgb-api-bridge-data:/data \
  ghcr.io/bilsectr/sgb-api-bridge:latest sync-once full

# State + feed'leri tamamen sil (sonraki acilis seed verisinden tekrar baslar)
docker run --rm -v sgb-api-bridge-data:/data alpine \
  sh -c "rm -rf /data/state /data/docs"
```

## Yapılandırma (env variables)

| Variable | Default | Açıklama |
|---|---|---|
| `SGB_BRIDGE_ROOT` | `/data` | State ve feed dosyalarının kök dizini |
| `SGB_BRIDGE_DELTA_INTERVAL_SEC` | `3600` | Loop modunda delta sync sıklığı (sn) |
| `SGB_BRIDGE_DELTA_MAX_PAGES` | `1000` | Delta'nın tek seferde gezeceği maks. sayfa (bayat state güvenlik tavanı) |
| `TZ` | `UTC` | Konteyner saat dilimi (loglar için) |

## Sorun giderme

- **404 dönüyor**: Seed verisi kopyalanmamış olabilir. `docker exec sgb-api-bridge ls -la /data/docs` ile kontrol et. Boşsa imajı kendin build ettiysen `docs/` klasörünü dahil etmemişsindir — `sync-once full` ile bootstrap et.
- **Konteyner sürekli restart oluyor**: SGB API'sine erişim yok ya da disk dolu. `docker logs sgb-api-bridge --tail 200` incele.
- **`Permission denied` /data altında**: Volume'un sahibi yanlış UID. Container `www-data` (UID 33) ile çalışır. Host'ta `chown -R 33:33 /var/lib/docker/volumes/sgb-api-bridge-data/_data` ile düzelt.
- **İmaj çekilemiyor**: Air-gapped ortamlarda `docker save / load` ile transferle:
  ```bash
  docker pull ghcr.io/bilsectr/sgb-api-bridge:latest
  docker save ghcr.io/bilsectr/sgb-api-bridge:latest | gzip > sgb-api-bridge.tar.gz
  # Hedef makineye kopyala:
  gunzip -c sgb-api-bridge.tar.gz | docker load
  ```

## İmajı kendin build etmek (supply-chain güvenliği)

```bash
git clone https://github.com/bilsectr/sgb-api-bridge.git
cd sgb-api-bridge
docker build -f docker/Dockerfile -t kurum/sgb-api-bridge:1.0 .
docker push kurum-registry.local/sgb-api-bridge:1.0
```
