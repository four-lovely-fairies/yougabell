---
name: create-pull-request
description: GitHub pull request를 생성·갱신하고 병합 충돌을 해결한다. PR 생성, PR 본문 수정, 브랜치 푸시, 충돌 해결 또는 리뷰 준비를 요청받을 때 사용한다. Markdown 본문을 파일로 전달하고 GitHub에서 렌더링·병합 가능 상태를 검증해야 하는 저장소 작업에 적용한다.
---

# Create Pull Request

## Workflow

1. 작업 트리와 현재 브랜치, base 브랜치, 기존 PR을 확인한다. 사용자의 미관련 변경은 건드리지 않는다.
2. `git fetch origin <base>` 후 base를 rebase한다. 충돌이 나면 변경 의도를 보존해 해결하고, 빌드·테스트를 다시 실행한다.
3. PR 본문은 Markdown 파일로 만든다. 셸 인수에 `\\n`을 넣지 않는다. 아래 형식을 사용한다.

```md
## 변경 사항

- 항목 1
- 항목 2

## 검증

- `pnpm lint`
- `pnpm build`
```

4. `gh pr create --body-file <body-file>` 또는 `gh pr edit --body-file <body-file>`로 본문을 반영한다. 본문 파일은 완료 후 삭제한다.
5. `gh pr view <number> --json body,mergeable,mergeStateStatus`로 다음을 확인한다.

- `body`에 실제 줄바꿈이 있고 `##` 제목과 목록이 렌더링 가능한 형태인지
- `mergeable`이 `MERGEABLE`, `mergeStateStatus`가 `CLEAN`인지

6. PR URL, 검증 결과, 충돌 해결 여부를 보고한다. PR 생성·갱신 후 base가 바뀌어 다시 충돌하면 같은 절차를 반복한다.

## Commands

```bash
git fetch origin main
git rebase origin/main

gh pr edit <number> --body-file /path/to/pr-body.md
gh pr view <number> --json body,mergeable,mergeStateStatus
```

푸시 전에는 해당 PR 브랜치에만 커밋이 있는지 확인하고, base 브랜치에는 직접 푸시하지 않는다.
