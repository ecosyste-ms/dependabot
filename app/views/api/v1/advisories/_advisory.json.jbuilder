json.extract! advisory, :uuid, :url, :title, :description, :origin, :severity, 
              :published_at, :withdrawn_at, :classification, :cvss_score, :cvss_vector,
              :references, :source_kind, :identifiers, :repository_url, :blast_radius,
              :packages, :epss_percentage, :epss_percentile, :created_at, :updated_at

json.issues_count advisory.issues_count
json.primary_identifier advisory.primary_identifier
json.ecosystems advisory.ecosystems