## Ractor bug when shelling out

I've got a script `main.rb` that uses Ractor. It creates 10 worker ractors and another ractor to pass jobs into those workers. The program does some work that eventually produces a file, (either using FileUtils.touch or `touch` with the shell). The program then checks the work was done by counting the files.

## Expected

When I run the program, it generates 1000 files

## Actual

When I run the program it generates 1000 files when using FileUtils.touch:

```
$ WORK=ruby ruby main.rb
<internal:ractor>:38: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
Expected 1000 files, and got 1000
```

But when I use `touch #{log_file}` it does not generate 1000 files:

```
$ WORK=shell ruby main.rb
<internal:ractor>:38: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
/Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1457:in `rmdir': Directory not empty @ dir_s_rmdir - /var/folders/hp/6rw6r3312z7b8pqpdgmcqb4c2rv3hv/T/d20200906-42477-hdlh6 (Errno::ENOTEMPTY)
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1457:in `block in remove_dir1'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1468:in `platform_support'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1456:in `remove_dir1'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1449:in `remove'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:780:in `block in remove_entry'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:1506:in `postorder_traverse'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/fileutils.rb:778:in `remove_entry'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/tmpdir.rb:97:in `ensure in mktmpdir'
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/tmpdir.rb:97:in `mktmpdir'
  from main.rb:40:in `<main>'
main.rb:55:in `block in <main>': Expected 1000 files, but only 203 (RuntimeError)
  from /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/tmpdir.rb:89:in `mktmpdir'
  from main.rb:40:in `<main>'
```

It appears that the `RACTORS.map(&:take)` is not blocking until all the ractors are done.

## SEGFAULT

If you try to add a puts statement then you get a segfault. When touching files with FileUtils it works correctly:

```
$ WORK=ruby PUTS_RACTORS=1 ruby main.rb
<internal:ractor>:38: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
done
done
done
done
done
done
done
done
done
done
Expected 1000 files, and got 1000
```

When shelling out:

```
$ WORK=shell PUTS_RACTORS=1 ruby main.rb
<internal:ractor>:38: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
main.rb:53: [BUG] Segmentation fault at 0x0000000000000044
ruby 3.0.0dev (2020-09-04T16:41:35Z master de30450d91) [x86_64-darwin19]

-- Crash Report log information --------------------------------------------
   See Crash Report log file under the one of following:
     * ~/Library/Logs/DiagnosticReports
     * /Library/Logs/DiagnosticReports
   for more details.
Don't forget to include the above Crash Report log file in bug reports.

-- Control frame information -----------------------------------------------
c:0007 p:---- s:0034 e:000033 CFUNC  :to_s
c:0006 p:---- s:0031 e:000030 CFUNC  :puts
c:0005 p:---- s:0028 e:000027 CFUNC  :puts
c:0004 p:0066 s:0023 e:000022 BLOCK  main.rb:53
c:0003 p:0055 s:0017 e:000016 METHOD /Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/tmpdir.rb:89
c:0002 p:0139 s:0007 E:000b48 EVAL   main.rb:40 [FINISH]
c:0001 p:0000 s:0003 E:001800 (none) [FINISH]

-- Ruby level backtrace information ----------------------------------------
main.rb:40:in `<main>'
/Users/rschneeman/.rubies/ruby-home/lib/ruby/3.0.0/tmpdir.rb:89:in `mktmpdir'
main.rb:53:in `block in <main>'
main.rb:53:in `puts'
main.rb:53:in `puts'
main.rb:53:in `to_s'

-- Machine register context ------------------------------------------------
 rax: 0x0000000000000000 rbx: 0x00007fe9b20ffeb0 rcx: 0x0000000103f12490
 rdx: 0x0000000000000000 rdi: 0x0000000000000034 rsi: 0x0000000000000000
 rbp: 0x00007ffeebe2b750 rsp: 0x00007ffeebe2b6f0  r8: 0x0000000000000000
  r9: 0x00007ffeebe2b8b8 r10: 0x00007fe9b0e05290 r11: 0x00007ffeebe2b8c8
 r12: 0x0000000000000000 r13: 0x0000000000000034 r14: 0x0000000000000000
 r15: 0x00007fe9b0e19e40 rip: 0x0000000103f12536 rfl: 0x0000000000010293

-- C level backtrace information -------------------------------------------
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_vm_bugreport+0x127) [0x104054387]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_bug_for_fatal_signal+0x1de) [0x103e76fee]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(sigsegv+0x5b) [0x103faddfb]
/usr/lib/system/libsystem_platform.dylib(_sigtramp+0x1d) [0x7fff712825fd]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(flo_to_s+0xa6) [0x103f12536]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(vm_call0_body+0x8e3) [0x104034e03]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_call0+0x641) [0x10404e471]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_funcall+0x1b3) [0x104036783]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_obj_as_string+0x3c) [0x103fc6aec]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_io_puts+0xb5) [0x103eba3a5]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(io_puts_ary+0xc8) [0x103eba528]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(exec_recursive+0x443) [0x103ff5303]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_io_puts+0xa7) [0x103eba397]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(vm_call0_body+0x8e3) [0x104034e03]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_call0+0x641) [0x10404e471]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_funcallv+0x55) [0x1040324d5]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(vm_call_cfunc_with_frame+0x151) [0x10404b811]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(vm_exec_core+0x389e) [0x10402997e]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_vm_exec+0xa8e) [0x10403ea3e]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(rb_ec_exec_node+0xb6) [0x103e81ca6]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(ruby_run_node+0x62) [0x103e81ba2]
/Users/rschneeman/.rubies/ruby-home/bin/ruby(main+0x71) [0x103dd40c1]
```

