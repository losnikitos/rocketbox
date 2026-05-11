# Postmark: pull remote templates, export React Email HTML, merge into ./postmark, push.
POSTMARK_DIR := ./postmark
OUT_DIR := out

.PHONY: postmark-sync postmark-pull postmark-export postmark-copy-html postmark-push

# Full pipeline (1–4)
postmark-sync: postmark-pull postmark-export postmark-copy-html postmark-push

postmark-pull:
	postmark templates pull --overwrite $(POSTMARK_DIR)

postmark-export:
	npm run export

# For each out/<name>.html → postmark/<name>/content.html (text files unchanged)
postmark-copy-html:
	@for f in $(OUT_DIR)/*.html; do \
		test -f "$$f" || continue; \
		base=$$(basename "$$f" .html); \
		mkdir -p "$(POSTMARK_DIR)/$$base"; \
		cp "$$f" "$(POSTMARK_DIR)/$$base/content.html"; \
	done

postmark-push:
	postmark templates push $(POSTMARK_DIR)
