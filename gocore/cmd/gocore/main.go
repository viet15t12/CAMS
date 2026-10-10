package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"runtime"

	"github.com/viet15t12/CAMS/gocore/internal/event"
	"github.com/viet15t12/CAMS/gocore/internal/protocol"
)

var version = "dev"

func main() {
	if err := run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) error {
	if len(args) == 0 {
		usage(stderr)
		return errors.New("a command is required")
	}
	switch args[0] {
	case "version":
		fmt.Fprintf(stdout, "gocore %s\n", version)
		return nil
	case "doctor":
		flags := flag.NewFlagSet("doctor", flag.ContinueOnError)
		flags.SetOutput(stderr)
		jsonOutput := flags.Bool("json", false, "print machine-readable JSON")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		report := map[string]any{
			"version": version, "go_version": runtime.Version(),
			"protocol_version": protocol.Version, "event_schema_version": event.SchemaVersion,
			"mode": "dry-run", "network_mutation": false,
		}
		if *jsonOutput {
			return json.NewEncoder(stdout).Encode(report)
		}
		fmt.Fprintf(stdout, "gocore=%s protocol=%d event_schema=%d mode=dry-run network_mutation=false\n",
			version, protocol.Version, event.SchemaVersion)
		return nil
	case "validate-event":
		flags := flag.NewFlagSet("validate-event", flag.ContinueOnError)
		flags.SetOutput(stderr)
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		if flags.NArg() > 1 {
			return errors.New("usage: gocore validate-event [FILE|-]")
		}
		reader := stdin
		if flags.NArg() == 1 && flags.Arg(0) != "-" {
			file, err := os.Open(flags.Arg(0))
			if err != nil {
				return err
			}
			defer file.Close()
			reader = file
		}
		value, err := event.Decode(reader)
		if err != nil {
			return err
		}
		return json.NewEncoder(stdout).Encode(map[string]any{
			"ok": true, "event_id": value.EventID, "event_type": value.EventType,
		})
	case "serve":
		flags := flag.NewFlagSet("serve", flag.ContinueOnError)
		flags.SetOutput(stderr)
		stdio := flags.Bool("stdio", false, "serve the JSON Lines protocol on stdin/stdout")
		if err := flags.Parse(args[1:]); err != nil {
			return err
		}
		if !*stdio || flags.NArg() != 0 {
			return errors.New("usage: gocore serve --stdio")
		}
		return protocol.NewServer(stdin, stdout).Run()
	case "help", "-h", "--help":
		usage(stdout)
		return nil
	default:
		usage(stderr)
		return fmt.Errorf("unknown command %q", args[0])
	}
}

func usage(writer io.Writer) {
	fmt.Fprintln(writer, "usage: gocore <version|doctor|validate-event|serve> [options]")
}
