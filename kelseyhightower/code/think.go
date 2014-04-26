type User struct {
        Uid      string // user id
        Gid      string // primary group id
        Username string
        Name     string
        HomeDir  string
}

func Lookup(username string) (*User, error)
