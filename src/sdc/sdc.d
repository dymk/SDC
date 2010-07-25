/**
 * Copyright 2010 Bernard Helyer
 * 
 * This file is part of SDC.
 * 
 * SDC is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
module sdc.sdc;

import std.stdio;
import std.getopt;
import std.process : system;
import std.c.stdlib;

import llvm.c.Analysis;
import llvm.c.BitWriter;
import llvm.c.Core;
import llvm.c.transforms.Scalar;

import sdc.source;
import sdc.tokenstream;
import sdc.lexer;
import sdc.compilererror;
import sdc.info;
import sdc.ast.all;
import sdc.parser.all;
import sdc.gen.base;

int main(string[] args)
{
    bool printTokens;
    
    getopt(args,
           "help", () { usage(); exit(0); },
           "version", () { stdout.writeln(NAME); exit(0); },
           "print-tokens", &printTokens
          );
          
    if (args.length == 1) {
        usage(); exit(1);
    }
    
    bool errors;
    foreach (arg; args[1 .. $]) {
        auto source = new Source(arg);
        TokenStream tstream;
        Module mod;
        LLVMModuleRef llvmMod;
        try {
            tstream = lex(source);
            mod = parseModule(tstream);
            llvmMod = genModule(mod);
        } catch (CompilerError) {
            errors = true;
            continue;
        }
        if (printTokens) tstream.printTo(stdout);
        LLVMVerifyModule(llvmMod, LLVMVerifierFailureAction.AbortProcess, null);
        LLVMWriteBitcodeToFile(llvmMod, "test.bc");
        optimise(llvmMod);
        LLVMDumpModule(llvmMod);
        system("llvm-ld -native test.bc");
        LLVMDisposeModule(llvmMod);
    }

    return errors ? 1 : 0;
}

void optimise(LLVMModuleRef mod)
{
    auto passManager = LLVMCreatePassManager();
    LLVMAddInstructionCombiningPass(passManager);
    LLVMAddPromoteMemoryToRegisterPass(passManager);
    LLVMRunPassManager(passManager, mod);
    LLVMDisposePassManager(passManager);
}

void usage()
{
    stdout.writeln("sdc [options] files");
    stdout.writeln("  --help:          print this message.");
    stdout.writeln("  --version:       print version information to stdout.");
    stdout.writeln("  --print-tokens:  print the results of tokenisation to stdout.");
}
