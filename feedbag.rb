#!/usr/bin/ruby

# Copyright  Axiombox (c) 2008
#            David Moreno <david@axiombox.com> (c) 2008

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Originally wrote by David Moreno <david@axiombox.com>
#  mainly based on Benjamin Trott's Feed::Find

require "rubygems"
require "hpricot"
require "open-uri"
require "net/http"

module Feedbag

	@content_types = [
		'application/x.atom+xml',
		'application/atom+xml',
		'application/xml',
		'text/xml',
		'application/rss+xml',
		'application/rdf+xml',
	]

	$feeds = []
	$base_uri = nil

	def self.find(url)
		$feeds = []

		url_uri = URI.parse(url)
		url = "#{url_uri.scheme or 'http'}://#{url_uri.host}#{url_uri.path}"

		begin
			html = open(url) do |f|
				if @content_types.include?(f.content_type.downcase)
					return self.add_feed(url, nil)
				end

				doc = Hpricot(f.read)

				if doc.at("base") and doc.at("base")["href"]
					$base_uri = doc.at("base")["href"]
				else
					$base_uri = nil
				end

				# first with links
				(doc/"link").each do |l|
					next unless l["rel"]
					if l["type"] and @content_types.include?(l["type"].downcase.strip) and (l["rel"].downcase =~ /alternate/i or l["rel"] == "service.feed")
						self.add_feed(l["href"], url, $base_uri)
					end
				end

				(doc/"a").each do |a|
					next unless a["href"]
					if self.looks_like_feed?(a["href"]) and (a["href"] =~ /\// or a["href"] =~ /#{url_uri.host}/)
						self.add_feed(a["href"], url, $base_uri)
					end
				end

				(doc/"a").each do |a|
					next unless a["href"]
					if self.looks_like_feed?(a["href"])
						self.add_feed(a["href"], url, $base_uri)
					end
				end

			end
		rescue OpenURI::HTTPError => the_error
			puts "Error ocurred with `#{url}': #{the_error}"
		rescue SocketError => err
			puts "Socket error ocurred with: `#{url}': #{err}"
		end
		
		$feeds
	end

	def self.looks_like_feed?(url)
		if url =~ /(\.(rdf|xml|rdf)$|feed=(rss|atom)|(atom|feed)\/$)/i
			true
		else
			false
		end
	end

	def self.add_feed(feed_url, orig_url, base_uri = nil)
		# puts "#{feed_url} - #{orig_url}"
		url = feed_url.sub(/^feed:/, '').strip

		if base_uri
			#	url = base_uri + feed_url
			url = URI.parse(base_uri).merge(feed_url).to_s
		end

		begin
			uri = URI.parse(url)
		rescue
			puts "Error with `#{url}'"
			exit 1
		end
		unless uri.absolute?
			orig = URI.parse(orig_url)
			url = orig.merge(url).to_s
		end

		# verify url is really valid
		$feeds.push(url) unless $feeds.include?(url)# if self._is_http_valid(URI.parse(url), orig_url)
	end

	def self._is_http_valid(uri, orig_url)
		req = Net::HTTP.get_response(uri)
		orig_uri = URI.parse(orig_url)
		case req
			when Net::HTTPSuccess then
				return true
			else
				return false
		end
	end
end

