require "forced_file_from_url/version"
require 'open-uri'

module ForcedFileFromUrl
  private

  # Using open-uri to open files that are less than 10kb will return a StringIO object.
  # This causes a problem when trying to call #path on the object which is not available
  # in StringIO objects but rather File and Tempfile objects. This method writes the data
  # to a Tempfile when the data is a StringIO.
  def forced_file_from_url(url)
    file = nil

    data = open URI.parse(url)
    if data.is_a? Tempfile
      file = data
    else
      extname = File.extname url
      basename = File.basename url, extname

      file = Tempfile.new [basename, extname]
      file.binmode
      file.write data.read
      file.rewind
    end

    if block_given?
      begin
        yield file
      ensure
        file.close
        file.unlink
      end
    else
      file
    end
  end

  # Takes a paperclip attachment, downloads the file to tmp, and returns a file handle
  def file_from_paperclip_attachment(attachment, style: :original)
    filename = attachment.instance_read :file_name
    extname = File.extname filename
    basename = File.basename filename, extname
    file = Tempfile.new([basename, extname])
    attachment.copy_to_local_file style, file.path
    file.rewind
    if block_given?
      begin
        yield file
      ensure
        file.close
        file.unlink
      end
    else
      file
    end
  end
end
