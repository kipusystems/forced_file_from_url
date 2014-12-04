# ForcedFileFromUrl

Tiny hack to convert StringIO objects into Tempfile when using OpenURI to open files less than 10kb. Inspired by [this Stackoverflow answer](http://stackoverflow.com/questions/6291733/storing-image-using-open-uri-and-paperclip-having-size-less-than-10kb).

## Use Case

When using OpenURI to #open a file that is less than 10kb will return a StringIO but in the case when we need to know the #path of the file StringIO won't work.

Use this Gem's #forced_file_from_url to write the StringIO data to a Tempfile and get the object you expected from OpenURI.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'forced_file_from_url'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install forced_file_from_url

## Usage

Include `ForcedFileFromUrl` in your code and use `forced_file_from_url(url)`. This method will always return a Tempfile.

## Contributing

1. Fork it ( https://github.com/DiegoSalazar/forced_file_from_url/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
