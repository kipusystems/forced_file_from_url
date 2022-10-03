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

    _handle_ff_file(file, &block)
  end

  # Takes a paperclip attachment, downloads the file to tmp, and returns a file handle
  def file_from_paperclip_attachment(attachment, style: :original, &block)
    filename = attachment.instance_read :file_name
    extname = File.extname filename
    basename = File.basename filename, extname
    file = Tempfile.new([basename, extname])
    attachment.copy_to_local_file style, file.path
    file.rewind

    _handle_ff_file(file, &block)
  end

  def with_file_from_url_cleanup
    yield if _within_ff_cleanup_block?
    open_files = _open_ff_files
    begin
      @__block_open = true
      yield
    ensure
      @open_files = []
      @__block_open = false
      open_files.each {|file|
        file.close
        file.unlink
      }
    end
  end

  def _open_ff_files
    @open_files ||= []
  end

  def _within_ff_cleanup_block?
    @__block_open
  end

  def _handle_ff_file(file, &block)
    if block_given?
      begin
        yield file
      ensure
        file.close
        file.unlink
      end
    elsif _within_ff_cleanup_block?
      # even if cleanup is forgotten it can be done on the next batch :evilsmile:
      _open_ff_files << file
      file
    else
      file.close
      file.unlink
      raise ArgumentError, "unsafe file cleanup practice detected!"
    end
  end
end
