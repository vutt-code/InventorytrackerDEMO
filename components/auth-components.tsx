import { signIn, signOut } from "../auth"

export function SignIn() {
  return (
    <form
      action={async () => {
        "use server"
        await signIn("google")
      }}
      style={{ display: "inline-block" }}
    >
      <button 
        type="submit" 
        style={{
          padding: "10px 20px",
          backgroundColor: "#4285F4",
          color: "white",
          border: "none",
          borderRadius: "4px",
          cursor: "pointer",
          fontWeight: "bold"
        }}
      >
        Sign in with Google
      </button>
    </form>
  )
}

export function SignOut() {
  return (
    <form
      action={async () => {
        "use server"
        await signOut()
      }}
      style={{ display: "inline-block" }}
    >
      <button 
        type="submit"
        style={{
          padding: "8px 16px",
          backgroundColor: "#f44336",
          color: "white",
          border: "none",
          borderRadius: "4px",
          cursor: "pointer",
          fontWeight: "bold",
          marginLeft: "10px"
        }}
      >
        Sign Out
      </button>
    </form>
  )
}
