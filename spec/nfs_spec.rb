require 'spec_helper'

describe 'NFS' do
  it 'supports directory listing' do
    files = Dir.chdir($dest_dir) do
      Dir.glob("*.*")
    end

    expect(files.sort).to eq(['file1.txt', 'file2.txt'].sort)
  end

  it 'supports reading files' do
    %w(file1.txt file2.txt).each do |file|
      orig_contents = File.read(File.join($orig_dir, file))
      dest_contents = File.read(File.join($dest_dir, file))
      expect(dest_contents).to eq(orig_contents)
    end
  end

  it 'supports file stats' do
    %w(file1.txt file2.txt).each do |file|
      orig_stat = File.lstat(File.join($orig_dir, 'file1.txt'))
      dest_stat = File.lstat(File.join($dest_dir, 'file1.txt'))
      expect(orig_stat.size).to eq(dest_stat.size)
      expect(orig_stat.mtime.to_i).to eq(dest_stat.mtime.to_i)
      expect(orig_stat.ctime.to_i).to eq(dest_stat.ctime.to_i)
    end
  end
end
