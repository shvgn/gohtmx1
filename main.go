package main

import (
	"context"
	"embed"
	"fmt"
	"io/fs"
	"strings"
	"sync"
	"time"

	"github.com/labstack/echo/v4"
	"k8s.io/apimachinery/pkg/util/rand"
)

//go:embed static
var static embed.FS

func newWordGen() *wordgen {
	g := &wordgen{}
	g.generate() // init
	return g
}

type wordgen struct {
	word string
	mu   sync.RWMutex
}

func (s *wordgen) generate() {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.word = strings.ToUpper(rand.String(12))
}

func (s *wordgen) get() string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return s.word
}

func main() {

	fmt.Println("known files: ")
	fs.WalkDir(static, ".", func(path string, d fs.DirEntry, err error) error {
		fmt.Println(path)
		return nil
	})

	state := newWordGen()
	go func() {
		for {
			time.Sleep(3 * time.Second)
			state.generate()
		}
	}()

	e := echo.New()
	e.GET("/", func(c echo.Context) error {
		component := page(state.get())
		component.Render(context.Background(), c.Response())
		return nil
	})

	e.GET("/fragments/code", func(c echo.Context) error {
		component := Code(state.get())
		component.Render(context.Background(), c.Response())
		return nil
	})

	e.POST("/fragments/generate", func(c echo.Context) error {
		state.generate()
		component := Code(state.get())
		component.Render(context.Background(), c.Response())
		return nil
	})

	e.StaticFS("static", echo.MustSubFS(static, "static"))
	e.Logger.Fatal(e.Start(":3000"))
}
