package tavola

import (
	"archive/tar"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Archive is the generated Tavola project archive.
type Archive struct {
	files map[string]ArchiveFile
}

type ArchiveFile struct {
	Path string
	Data []byte
	Mode int64
}

func NewArchive() *Archive {
	return &Archive{files: map[string]ArchiveFile{}}
}

func (a *Archive) Add(path string, data []byte) {
	a.AddMode(path, data, 0644)
}

func (a *Archive) AddString(path, data string) {
	a.Add(path, []byte(data))
}

func (a *Archive) AddMode(path string, data []byte, mode int64) {
	if a.files == nil {
		a.files = map[string]ArchiveFile{}
	}
	clean := filepath.ToSlash(filepath.Clean(path))
	if clean == "." || clean == "" || clean[0] == '/' || clean == ".." || strings.HasPrefix(clean, "../") {
		panic(fmt.Sprintf("invalid archive path %q", path))
	}
	a.files[clean] = ArchiveFile{Path: clean, Data: append([]byte(nil), data...), Mode: mode}
}

func (a *Archive) Files() []ArchiveFile {
	files := make([]ArchiveFile, 0, len(a.files))
	for _, file := range a.files {
		files = append(files, file)
	}
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return files
}

func (a *Archive) WriteTar(path string) error {
	var buf bytes.Buffer
	if err := a.WriteTarTo(&buf); err != nil {
		return err
	}
	return os.WriteFile(path, buf.Bytes(), 0644)
}

func (a *Archive) WriteTarTo(w io.Writer) error {
	tw := tar.NewWriter(w)
	for _, file := range a.Files() {
		mode := file.Mode
		if mode == 0 {
			mode = 0644
		}
		if err := tw.WriteHeader(&tar.Header{
			Name: file.Path,
			Mode: mode,
			Size: int64(len(file.Data)),
		}); err != nil {
			return err
		}
		if _, err := tw.Write(file.Data); err != nil {
			return err
		}
	}
	return tw.Close()
}

func (a *Archive) WriteDir(root string) error {
	if err := os.MkdirAll(root, 0755); err != nil {
		return err
	}
	for _, file := range a.Files() {
		path := filepath.Join(root, filepath.FromSlash(file.Path))
		if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
			return err
		}
		mode := file.Mode
		if mode == 0 {
			mode = 0644
		}
		if err := os.WriteFile(path, file.Data, os.FileMode(mode)); err != nil {
			return err
		}
	}
	return nil
}
