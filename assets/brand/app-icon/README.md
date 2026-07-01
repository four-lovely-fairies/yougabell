# 앱 아이콘 (육아벨 마스코트)

> 모든 레포(web · admin · mobile)의 파비콘·앱 아이콘 **단일 진실의 소스**.
> 디자인 변경 시 여기 마스터를 갱신한 뒤 각 레포로 전파한다.

## 출처

- Figma: `① Icon` 섹션 — iOS App Icon(1024) · Play Store Icon(512)
  - node-id `2443:4762` (파일 `sKdG5GEBZPdMjFY9nYj5g0`)

## 마스터 파일

| 파일                  | 용도                                          |
| --------------------- | --------------------------------------------- |
| `app-icon.svg`        | 벡터 마스터. web/admin `app/icon.svg`로 사용  |
| `app-icon-1024.png`   | 래스터 마스터(1024). 모든 PNG 파생의 원본     |
| `play-store-icon.svg` | Play Store 등록용 벡터                        |

## 팔레트

| 역할        | HEX       |
| ----------- | --------- |
| 배경        | `#EEE4FF` |
| 마스코트 몸 | `#C3ADF5` |
| 눈          | `#FEFFFB` |
| 동공·입     | `#45374E` |

## 파생 규격

- **web/admin**: `app/icon.svg`, `app/apple-icon.png`(180), `app/favicon.ico`(16/32/48), PWA `public/icons/icon-192.png`·`icon-512.png`
- **mobile(Expo)**: `assets/images/icon.png`(1024), `favicon.png`, `splash-icon.png`, `android-icon-foreground.png` + adaptiveIcon `backgroundColor #EEE4FF`
