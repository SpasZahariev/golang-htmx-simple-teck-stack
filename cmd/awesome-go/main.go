// main.go

package main

import (
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

func main() {
	InitDatabase()
	defer DB.Close()

	e := gin.Default()

	e.LoadHTMLGlob("templates/*")

	e.POST("/todos", func(c *gin.Context) {
		title := c.PostForm("title")
		status := c.PostForm("status")
		id, err := CreateToDo(title, status)
		if err != nil {
			log.Fatal(err)
		}
		c.HTML(http.StatusOK, "task.html", gin.H{
			"Title":  title,
			"Status": status,
			"Id":     id,
		})
	})

	e.DELETE("/todos/:id", func(c *gin.Context) {
		param := c.Param("id")
		id, err := strconv.ParseInt(param, 10, 64)
		if err != nil {
			log.Fatal(err)
		}
		DeleteToDo(id)
		c.Status(http.StatusOK) //Respond with a 200 OK status and no content
		// Handle response, e.g., return a success message
	})

	e.GET("/", func(c *gin.Context) {
		todos := ReadToDoList()
		c.HTML(http.StatusOK, "index.html", gin.H{"todos": todos})
	})

	e.Run(":8080")
}
