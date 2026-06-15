#!/bin/bash
# org-review-prs 플러그인 로컬 설정 예시.
#
# 사용법:
#   1) 이 파일을 config.sh 로 복사   →   cp config.example.sh config.sh
#   2) 아래 값 중 바꾸고 싶은 것만 수정
#   3) ./install.sh 실행            →   ~/.config/swiftbar/org-review-prs.config.sh 로 배치됨
#
# config.sh 는 .gitignore 되어 커밋되지 않는다(개인 환경 전용).
# 이 파일을 만들지 않으면 플러그인이 내장 기본값(아래와 동일)을 그대로 쓴다.

# review-requested 검색 대상 GitHub org
ORG="thefarmersfront"

# "리뷰 대기"로 인정할 라벨 prefix. 이 문자열로 "시작"하는 라벨이 붙은 PR만 노출.
#   예) "리뷰요청" → "리뷰요청", "리뷰요청-프론트" 등 자동 포함 / "리뷰완료"·무라벨 제외
# 빈 문자열("")이면 라벨 필터 없이 review-requested 받은 PR 전부 표시.
LABEL_PREFIX="리뷰요청"

# 검색 결과 페이지당 최대 건수 (기본 50)
PER_PAGE=50

# ── 갱신 주기는 이 파일이 아니라 플러그인 "파일명"으로 정한다 ──
#   org-review-prs.5m.sh  → 5분 주기.  2m / 10m 등으로 rename 하면 바뀐다.
#   (gh 토큰은 시간당 5000 req라 짧게 둬도 여유)
