require "forced_file_from_url/version"
require 'open-uri'

module ForcedFileFromUrl
  private

  # Using open-uri to open files that are less than 10kb will return a StringIO object.
  # This causes a problem when trying to call #path on the object which is not available
  # in StringIO objects but rather File and Tempfile objects. This method writes the data 
  # to a Tempfile when the data is a StringIO.
  def forced_file_from_url(url)
    data = open URI.parse(url)
    return data if data.is_a? Tempfile

    extname = File.extname url
    basename = File.basename url, extname

    file = Tempfile.new [basename, extname]
    file.binmode
    file.write data.read
    file.rewind
    file
  end

  # Takes a paperclip attachment, downloads the file to tmp, and returns a file handle
  def file_from_paperclip_attachment(attachment, style: :original)
    url = Rails.root.join("/tmp/#{attachment.instance_read :file_name}").to_s
    attachment.copy_to_local_file style, url
    File.open url, ?r
  end
end
