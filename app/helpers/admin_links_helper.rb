# frozen_string_literal: true

module AdminLinksHelper
  # Unique suffix for admin-link popovers.
  # Must be unique across the whole page — the same record can render twice.
  def admin_link_id_suffix
    "-#{SecureRandom.hex(4)}"
  end
end
