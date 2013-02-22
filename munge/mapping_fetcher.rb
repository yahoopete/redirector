require 'csv'
require 'uri'
require 'net/http'
require 'pathname'

require_relative 'csv_source'
require_relative 'reporter'

class MappingFetcher
  attr_reader :csv_url

  def initialize(reporter = Reporter.new)
    @new_url_mappings = {
      'tna' => ''
    }
    @sources = []
    @reporter = reporter
  end

  def add_source(source)
    @sources << source
  end

  def input_csv
    @sources.map {|s| s.input_csv.to_a}.flatten(1)
  end

  def remap_new_urls_using(admin_url_mapping_csv_file)
    data = File.open(admin_url_mapping_csv_file, 'r:utf-8') { |f| f.read}

    CSV.parse(data, headers: true, header_converters: [NilAsBlankConverter, :downcase]).each do |row|
      if row['admin url'] =~ /whitehall-admin/ && row['new url'] && !row['new url'].empty?
        @new_url_mappings[row['admin url']] = row['new url']
      end
    end
  end

  def fetch
    headers = ['old url', 'new url', 'status', 'source', 'row_number']
    CSV do |csv|
      csv << headers
      input_csv.each do |line|
        csv << headers.map {|header| line[header] }
      end
    end
  end

  def munge(input)
    CSV.generate do |output_csv|
      $stderr.puts "Writing mappings"
      output_csv << ['Old Url', 'New Url', 'Status']
      i = 0
      rows = ensure_no_duplicates(remap_new_urls(skip_rows_with_blank_or_invalid_old_url(input)))
      rows.each do |row|
        new_row = [
          row['old url'],
          row['new url'],
          row['status']
        ]
        validate_row!(new_row)
        output_csv << new_row
        i += 1
      end
      $stderr.puts "Wrote #{i} mappings"
    end
  end

  def national_archive?(url)
    url == "TNA"
  end

  def remap_new_urls(rows)
    Enumerator.new do |yielder|
      rows.each do |row|
        new_url = remap_new_url(row['new url'])
        new_url = ensure_new_url_uses_https_for_govuk(new_url)
        if !blank?(new_url) && !valid_destination_url?(new_url)
          @reporter.invalid_new_url(row, new_url) unless national_archive?(new_url)
          new_url = ""
        end
        yielder << {
          'source' => row['source'],
          'row_number' => row['row_number'],
          'old url' => row['old url'],
          'new url' => new_url,
          'status'  => row['status']
        }
      end
    end
  end

  def skip_rows_with_blank_or_invalid_old_url(rows)
    Enumerator.new do |yielder|
      rows.each_with_index do |row, i|
        if blank?(row['old url'])
          @reporter.blank_old_url(row)
        elsif !valid_url?(row['old url'])
          @reporter.invalid_old_url(row)
        else
          yielder << row
        end
      end
    end
  end

  def duplicates(rows)
    rows.group_by {|row| row['old url']}.select { |old_url, cluster| cluster.size > 1}
  end

  def non_duplicates(rows)
    rows.group_by {|row| row['old url']}.reject { |old_url, cluster| cluster.size > 1}.map {|old_url, rr| rr.first}
  end

  def prefer_page_destinations_over_assets(rows)
    deduped_clusters = duplicates(rows).map do |old_url, cluster|
      dedup_cluster(cluster)
    end
    deduped_clusters.flatten(1) + non_duplicates(rows)
  end

  def dedup_cluster(cluster)
    categories = cluster.map {|row| row['new url']}.uniq.map {|new_url| categorise_new_url(new_url)}
    if categories.size == 2 && categories.include?(:asset) && categories.include?(:page)
      cluster.select {|row| categorise_new_url(row) == :page }
    elsif non_blank = cluster.find {|row| !blank?(row['new url']) }
      [non_blank]
    else
      [cluster.first]
    end
  end

  def remap_new_url(new_url)
    #p "REMAP: #{new_url} => FOUND? #{@new_url_mappings[new_url] || 'no'}"
    @new_url_mappings[new_url] || new_url
  end

  class CircularDependency < Struct.new(:url)
    def handle_result(yielder, reporter, row)
      reporter.circular_dependency(url, row)
    end
  end

  class UrlChainCompleted < Struct.new(:url)
    def handle_result(yielder, reporter, row)
      yielder << {
        'source' => row['source'],
        'row_number' => row['row_number'],
        'old url' => row['old url'],
        'new url' => url,
        'status'  => row['status']
      }
    end
  end

  def follow_url_chains(rows)
    mapping = rows_as_mapping(rows)
    Enumerator.new do |yielder|
      rows.each do |row|
        follow_url_chain(row, mapping).handle_result(yielder, @reporter, row)
      end
    end
  end

  def rows_as_mapping(rows)
    rows.inject({}) do |output, row|
      output.tap { |hash| hash[row['old url']] = row['new url'] }
    end
  end

  def follow_url_chain(row, mapping)
    urls = [row['new url']]
    while(mapping.include?(urls.last))
      new_url = mapping[urls.last]
      return CircularDependency.new(new_url) if urls.include?(new_url)
      urls << new_url
    end
    UrlChainCompleted.new(urls.last)
  end

  def ensure_new_url_uses_https_for_govuk(new_url)
    if new_url && new_url.start_with?("http://www.gov.uk/")
      new_url.sub(%r{^http://www\.gov\.uk/}, "https://www.gov.uk/")
    elsif new_url && new_url.start_with?("www.gov.uk/")
      new_url.sub(%r{^www\.gov\.uk/}, "https://www.gov.uk/")
    else
      new_url
    end
  end

  def categorise_new_url(new_url)
    case new_url
    when %r{https://www\.gov\.uk/government/uploads/} then :asset
    when %r{https://www\.gov\.uk/government/} then :page
    else nil
    end
  end

  def ensure_no_duplicates(rows)
    deduped = prefer_page_destinations_over_assets(rows)
    if duplicates(deduped).any?
      dup_description = duplicates(deduped).map {|url, c| "#{url} -> \n  #{c.map {|r| r['new url']}.join("\n  ")}"}.join("\n")
      raise "There were some duplicates old urls: '#{dup_description}'"
    end
    deduped
  end

  def valid_destination_url?(url)
    must_not_be_whitehall_admin!(url)
    !on_national_archives?(url) && !is_whitehall_admin?(url) && valid_url?(url)
  end

  def is_whitehall_admin?(url)
    url =~ /whitehall-admin/
  end

  def must_not_be_whitehall_admin!(url)
    @reporter.new_url_is_admin_url(url) if is_whitehall_admin?(url)
  end

  def blank?(url)
    url.nil? || url.strip.empty?
  end

  def on_national_archives?(url)
    url && url.start_with?("http://webarchive.nationalarchives.gov.uk/")
  end

  def validate_row!(new_row)
    new_row[0..1].each do |url|
      next if url.nil? || url.empty?
      valid_url?(url) || raise("Invalid URL: '#{url}'")
    end
  end

  def valid_url?(url)
    url && url =~ %r{^https?://} && URI.parse(url)
  rescue
    false
  end
end
