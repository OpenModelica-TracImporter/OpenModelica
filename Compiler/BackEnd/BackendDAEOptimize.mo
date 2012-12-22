/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-CurrentYear, Linköping University,
 * Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3
 * AND THIS OSMC PUBLIC LICENSE (OSMC-PL).
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES RECIPIENT'S
 * ACCEPTANCE OF THE OSMC PUBLIC LICENSE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from Linköping University, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS
 * OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

encapsulated package BackendDAEOptimize
" file:        BackendDAEOptimize.mo
  package:     BackendDAEOptimize
  description: BackendDAEOPtimize contains functions that do some kind of
               optimazation on the BackendDAE datatype:
               - removing simpleEquations
               - Tearing/Relaxation
               - Linearization
               - Inline Integration
               - and so on ... 
               
  RCS: $Id$"

public import Absyn;
public import BackendDAE;
public import DAE;
public import Env;
public import HashTable2;
//public import IndexReduction;

protected import BackendDAEEXT;
protected import BackendDAETransform;
protected import BackendDAEUtil;
protected import BackendDump;
protected import BackendEquation;
protected import BackendVarTransform;
protected import BackendVariable;
protected import BaseHashTable;
protected import BaseHashSet;
protected import Builtin;
protected import Ceval;
protected import ClassInf;
protected import ComponentReference;
protected import DAEUtil;
protected import Debug;
protected import Derive;
protected import Expression;
protected import ExpressionDump;
protected import ExpressionSolve;
protected import ExpressionSimplify;
protected import Error;
protected import Flags;
protected import Graph;
protected import HashSet;
protected import HashTableExpToIndex;
protected import Inline;
protected import List;
protected import Matching;
protected import SCode;
protected import System;
protected import Types;
protected import Util;
protected import Values;
protected import ValuesUtil;




/*
 * inline arrayeqns stuff
 *
 */
public function inlineArrayEqn "function inlineArrayEqn
  author: Frenkel TUD 2011-3"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,inlineArrayEqn1,false);
end inlineArrayEqn;

public function inlineArrayEqnShared "function inlineArrayEqnShared"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match(inDAE)
    local
      BackendDAE.Variables ordvars,knvars,exobj,knvars1,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns,eqns1,inieqns1,remeqns1,eqns2;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcTree;
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EventInfo ev;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs,systs1;
      BackendDAE.Shared shared;
      list<BackendDAE.Var> ordvarslst;
      list<BackendDAE.Equation> eqnslst;
      Boolean b;
    case (_) then inDAE;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,ev,eoc,btp,symjacs)))
      equation
        eqnslst = BackendEquation.equationList(inieqns);
        (eqnslst,b) = getScalarArrayEqns(eqnslst,{},false);
        inieqns = Debug.bcallret1(b,BackendEquation.listEquation,eqnslst,inieqns);
        eqnslst = BackendEquation.equationList(remeqns);
        (eqnslst,b) = getScalarArrayEqns(eqnslst,{},false);
        remeqns = Debug.bcallret1(b,BackendEquation.listEquation,eqnslst,remeqns);
      then 
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,ev,eoc,btp,symjacs));
  end match;
end inlineArrayEqnShared;

protected function inlineArrayEqn1 "function: inlineArrayEqn1
  author: Frenkel TUD 2011-5"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedOptimized;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedOptimized;
algorithm
  (osyst,osharedOptimized) := matchcontinue (isyst,sharedOptimized)
    local
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns;
      list<BackendDAE.Equation> eqnslst;
      Integer oldsize,newsize;
      BackendDAE.Matching matching;
      Option<BackendDAE.IncidenceMatrix> m;
      Option<BackendDAE.IncidenceMatrixT> mT;
      BackendDAE.StateSets stateSets;
    case (syst as BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,m=m,mT=mT,matching=matching,stateSets=stateSets),(shared,_))
      equation
        eqnslst = BackendEquation.equationList(eqns);
        (eqnslst,true) = getScalarArrayEqns(eqnslst,{},false);
        eqns = BackendEquation.listEquation(eqnslst);
      then
        (BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets),(shared,true));
    else
      then
        (isyst,sharedOptimized);
  end matchcontinue;
end inlineArrayEqn1;

public function getScalarArrayEqns
  input list<BackendDAE.Equation> iEqsLst;
  input list<BackendDAE.Equation> iAcc;
  input Boolean iFound;
  output list<BackendDAE.Equation> oEqsLst;
  output Boolean oFound;
algorithm
  (oEqsLst,oFound) := match(iEqsLst,iAcc,iFound)
    local
      BackendDAE.Equation eqn;
      list<BackendDAE.Equation> eqns,eqns1;
      Boolean b;
    case ({},_,_) then (listReverse(iAcc),iFound);
    case (eqn::eqns,_,_)
     equation
       (eqns1,b) = getScalarArrayEqns1(eqn,iAcc);
       (eqns1,b) = getScalarArrayEqns(eqns,eqns1,b or iFound);
     then
       (eqns1,b);
  end match;
end getScalarArrayEqns;

protected function getScalarArrayEqns1"
  author: Frenkel TUD 2012-06"
  input  BackendDAE.Equation iEqn;
  input list<BackendDAE.Equation> iAcc;
  output list<BackendDAE.Equation> outEqsLst;
  output Boolean oFound;
algorithm
  (outEqsLst,oFound) := matchcontinue (iEqn,iAcc)
    local
      DAE.ElementSource source;
      DAE.Exp e1,e2,e1_1,e2_1;
      list<DAE.Exp> ea1,ea2;
      list<BackendDAE.Equation> eqns;
      Boolean diffed;
    case (BackendDAE.ARRAY_EQUATION(left=e1,right=e2,source=source,differentiated=diffed),_)
      equation
        true = Expression.isArray(e1) or Expression.isMatrix(e1);
        true = Expression.isArray(e2) or Expression.isMatrix(e2);
        ea1 = Expression.flattenArrayExpToList(e1);
        ea2 = Expression.flattenArrayExpToList(e2);
        eqns = List.threadFold2(ea1,ea2,generateScalarArrayEqns2,source,diffed,iAcc);
      then
        (eqns,true);
    case (BackendDAE.ARRAY_EQUATION(left=e1 as DAE.CREF(componentRef =_),right=e2,source=source,differentiated=diffed),_)
      equation
        true = Expression.isArray(e2) or Expression.isMatrix(e2);
        ((e1_1,(_,_))) = BackendDAEUtil.extendArrExp((e1,(NONE(),false)));
        ea1 = Expression.flattenArrayExpToList(e1_1);
        ea2 = Expression.flattenArrayExpToList(e2);
        eqns = List.threadFold2(ea1,ea2,generateScalarArrayEqns2,source,diffed,iAcc);
      then
        (eqns,true);
    case (BackendDAE.ARRAY_EQUATION(left=e1,right=e2 as DAE.CREF(componentRef =_),source=source,differentiated=diffed),_)
      equation
        true = Expression.isArray(e1) or Expression.isMatrix(e1);
        ((e2_1,(_,_))) = BackendDAEUtil.extendArrExp((e2,(NONE(),false)));
        ea1 = Expression.flattenArrayExpToList(e1);
        ea2 = Expression.flattenArrayExpToList(e2_1);
        eqns = List.threadFold2(ea1,ea2,generateScalarArrayEqns2,source,diffed,iAcc);
      then
        (eqns,true);
    case (BackendDAE.ARRAY_EQUATION(left=e1 as DAE.CREF(componentRef =_),right=e2 as DAE.CREF(componentRef =_),source=source,differentiated=diffed),_)
      equation
        ((e1_1,(_,_))) = BackendDAEUtil.extendArrExp((e1,(NONE(),false)));
        ((e2_1,(_,_))) = BackendDAEUtil.extendArrExp((e2,(NONE(),false)));
        ea1 = Expression.flattenArrayExpToList(e1_1);
        ea2 = Expression.flattenArrayExpToList(e2_1);
        eqns = List.threadFold2(ea1,ea2,generateScalarArrayEqns2,source,diffed,iAcc);
      then
        (eqns,true);
    case (BackendDAE.COMPLEX_EQUATION(left=e1,right=e2,source=source,differentiated=diffed),_)
      equation
        ea1 = Expression.splitRecord(e1,Expression.typeof(e1));
        ea2 = Expression.splitRecord(e2,Expression.typeof(e2));
        eqns = List.threadFold2(ea1,ea2,generateScalarArrayEqns2,source,diffed,iAcc);
      then
        (eqns,true);        
    case (_,_) then (iEqn::iAcc,false);
  end matchcontinue;
end getScalarArrayEqns1;

protected function generateScalarArrayEqns2 "function generateScalarArrayEqns2
  author: Frenkel TUD 2012-06"
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.ElementSource source;
  input Boolean diffed;
  input list<BackendDAE.Equation> iEqns;
  output list<BackendDAE.Equation> oEqns;
algorithm
  oEqns := matchcontinue(inExp1,inExp2,source,diffed,iEqns)
    local
      Expression.Type tp;
      Integer size;
      DAE.Dimensions dims;
      list<Integer> ds;
      Boolean b1,b2;
    // complex types to complex equations  
    case (_,_,_,_,_)
      equation 
        tp = Expression.typeof(inExp1);
        true = DAEUtil.expTypeComplex(tp);
        size = Expression.sizeOf(tp);
      then
        BackendDAE.COMPLEX_EQUATION(size,inExp1,inExp2,source,diffed)::iEqns;
      
    // array types to array equations  
    case (_,_,_,_,_)
      equation 
        tp = Expression.typeof(inExp1);
        true = DAEUtil.expTypeArray(tp);
        dims = Expression.arrayDimension(tp);
        ds = Expression.dimensionsSizes(dims);
      then
        BackendDAE.ARRAY_EQUATION(ds,inExp1,inExp2,source,diffed)::iEqns;
    // other types  
    case (_,_,_,_,_)
      equation
        tp = Expression.typeof(inExp1);
        b1 = DAEUtil.expTypeComplex(tp);
        b2 = DAEUtil.expTypeArray(tp);
        false = b1 or b2;
        //Error.assertionOrAddSourceMessage(not b1,Error.INTERNAL_ERROR,{str}, Absyn.dummyInfo);
      then
        BackendDAE.EQUATION(inExp1,inExp2,source,diffed)::iEqns;
    else
      equation
        // show only on failtrace!
        true = Flags.isSet(Flags.FAILTRACE);
        Debug.traceln("- BackendDAEOptimize.generateScalarArrayEqns2 failed on: " +& ExpressionDump.printExpStr(inExp1) +& " = " +& ExpressionDump.printExpStr(inExp2) +& "\n");
      then
        fail();      
  end matchcontinue;  
end generateScalarArrayEqns2;




/*
 * inline functions stuff
 *
 */
public function lateInlineFunction "function lateInlineFunction"
    input BackendDAE.BackendDAE inDAE;
    output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := Inline.inlineCalls({DAE.NORM_INLINE(),DAE.AFTER_INDEX_RED_INLINE()},inDAE);
end lateInlineFunction;




/*
 * remove simply equations stuff
 *
 */


protected function updateEquationSystemMatching
" function: updateEquationSystemMatching
  author: Frenkel TUD 2012-09"
  input BackendDAE.Variables ordvars;
  input BackendDAE.EquationArray eqns;
  input array<Integer> ass1 "ass[varindx]=eqnindx";
  input array<Integer> ass2 "ass[eqnindx]=varindx";
  input BackendDAE.StrongComponents comps;
  input BackendDAE.StateSets stateSets;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := matchcontinue(ordvars,eqns,ass1,ass2,comps,stateSets)
    local
      array<list<BackendDAE.CrefIndex>> crefIdxLstArr;
      Integer bucketSize,numberOfVars,size,neqns,nvars,arrSizeEqns,arrSizeVars,neqns1,nvars1;
      array<Option<BackendDAE.Var>> varOptArr;
      array<Option<BackendDAE.Equation>> equOptArr;
      array<Integer> eqnindxs,varindxs;
      BackendDAE.StrongComponents comps_1;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns1;
      BackendDAE.VariableArray varArr;
    case(BackendDAE.VARIABLES(varArr=BackendDAE.VARIABLE_ARRAY(nvars,arrSizeVars,varOptArr),bucketSize=bucketSize),
         BackendDAE.EQUATION_ARRAY(size, neqns, arrSizeEqns, equOptArr),
         _,_,_,_)
      equation
        // update equationsarray
        eqnindxs = arrayCreate(neqns,-1);
        neqns1 = updateEquationArray(1,neqns,1,equOptArr,ass1,ass2,eqnindxs);
        // update variablearray
        varindxs = arrayCreate(nvars,-1);
        crefIdxLstArr = arrayCreate(bucketSize, {});
        nvars1 = updateVarArray(1,nvars,1,varOptArr,crefIdxLstArr,bucketSize,ass1,ass2,varindxs);
        // update strongComponents
        comps_1 = List.fold2(comps,updateStrongComponent,varindxs,eqnindxs,{});
        comps_1 = listReverse(comps_1);
        // generate updated data structs
        varArr = BackendDAE.VARIABLE_ARRAY(nvars1,arrSizeVars,varOptArr);
        vars = BackendDAE.VARIABLES(crefIdxLstArr, varArr, bucketSize, nvars1);
        eqns1 = BackendDAE.EQUATION_ARRAY(size, neqns1, arrSizeEqns, equOptArr);
      then
        BackendDAE.EQSYSTEM(vars,eqns1,NONE(),NONE(),BackendDAE.MATCHING(ass1,ass2,comps_1),stateSets);
    else
      equation
        print("BackendDAEOptimize.updateEquationSystemMatching failed\n");
      then
        fail();     
  end matchcontinue;
end updateEquationSystemMatching;

protected function updateStrongComponent
" function: updateStrongComponent
  author: Frenkel TUD 2012-09"
  input BackendDAE.StrongComponent iComp;
  input array<Integer> varindxs;
  input array<Integer> eqnindxs;
  input BackendDAE.StrongComponents iAcc;
  output BackendDAE.StrongComponents oComps;
algorithm
  oComps := matchcontinue(iComp,varindxs,eqnindxs,iAcc)
    local
      BackendDAE.StrongComponents comps;
      BackendDAE.StrongComponent comp;
      Integer v,e;
      list<Integer> vars,eqns;
      BackendDAE.JacobianType jacType;
      Boolean b;
      list<tuple<Integer,list<Integer>>> eqnvartpllst;
    case (BackendDAE.SINGLEEQUATION(eqn=e,var=v),_,_,_)
      equation
        e = eqnindxs[e];
        v = varindxs[v];
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLEEQUATION(e,v), iAcc);
      then
        comps;
    case (BackendDAE.EQUATIONSYSTEM(eqns=eqns,vars=vars,jacType=jacType),_,_,_)
      equation
        eqns = List.map1r(eqns,arrayGet,eqnindxs);
        eqns = List.select1(eqns,intGt,0);
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        e::_ = eqns;
        v::_ = vars;
        comp = Util.if_(intEq(listLength(eqns),1),BackendDAE.SINGLEEQUATION(e,v),BackendDAE.EQUATIONSYSTEM(eqns,vars,NONE(),jacType));
        comps = List.consOnTrue(intGt(listLength(eqns),0), comp, iAcc);
      then
        comps;
    case (BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=comp,disc_eqns=eqns,disc_vars=vars),_,_,_)
      equation
        comp::_ =updateStrongComponent(comp,varindxs,eqnindxs,{});
        eqns = List.map1r(eqns,arrayGet,eqnindxs);
        eqns = List.select1(eqns,intGt,0);
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comp = Util.if_(intEq(listLength(eqns),0),comp,BackendDAE.MIXEDEQUATIONSYSTEM(comp,eqns,vars));
        comps = List.consOnTrue(intGt(listLength(eqns),0), comp, iAcc);
      then
        comps;
    case (BackendDAE.SINGLEIFEQUATION(eqn=e,vars=vars),_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLEIFEQUATION(e,vars), iAcc);
      then
        comps;
    case (BackendDAE.SINGLEARRAY(eqn=e,vars=vars),_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLEARRAY(e,vars), iAcc);
      then
        comps;
    case (BackendDAE.SINGLEALGORITHM(eqn=e,vars=vars),_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLEALGORITHM(e,vars), iAcc);
      then
        comps;
    case (BackendDAE.SINGLECOMPLEXEQUATION(eqn=e,vars=vars),_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLECOMPLEXEQUATION(e,vars), iAcc);
      then
        comps;
    case (BackendDAE.SINGLEWHENEQUATION(eqn=e,vars=vars),_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        comps = List.consOnTrue(intGt(e,0), BackendDAE.SINGLEWHENEQUATION(e,vars), iAcc);
      then
        comps;
    case (BackendDAE.TORNSYSTEM(tearingvars=vars,residualequations=eqns,otherEqnVarTpl=eqnvartpllst,linear=b),_,_,_)
      equation
        eqns = List.map1r(eqns,arrayGet,eqnindxs);
        eqns = List.select1(eqns,intGt,0);
        vars = List.map1r(vars,arrayGet,varindxs);
        vars = List.select1(vars,intGt,0);
        eqnvartpllst = updateTornSystemComp(eqnvartpllst,varindxs,eqnindxs,{});
        comp = BackendDAE.TORNSYSTEM(vars,eqns,eqnvartpllst,b);
      then
        comp::iAcc;
    case (_,_,_,_)
      equation
        print("BackendDAEOptimize.updateStrongComponent failed for Comp:\n");
        BackendDump.dumpComponent(iComp);
        print("Size EqnsIndx: " +& intString(arrayLength(eqnindxs)) +& "\n");
        print("Size VarsIndx: " +& intString(arrayLength(varindxs)) +& "\n");
      then
        fail();
  end matchcontinue;
end updateStrongComponent;

protected function updateEquationSystemComp
  input list<Integer> eqns;
  input list<Integer> vars;
  input BackendDAE.JacobianType jacType;
  input BackendDAE.StrongComponents iAcc;
  output BackendDAE.StrongComponents oComps;
algorithm
  oComps := match(eqns,vars,jacType,iAcc)
    local
      Integer e,v;
    case ({},{},_,_) then iAcc;
    case ({},v::_,_,_)
      //equation
      then 
        fail();
    case (e::{},v::_,_,_) 
      then
        BackendDAE.SINGLEEQUATION(e,v)::iAcc;
    case (_,_,_,_)
      then
        BackendDAE.EQUATIONSYSTEM(eqns,vars,NONE(),jacType)::iAcc; 
  end match; 
end updateEquationSystemComp;

protected function updateTornSystemComp
  input list<tuple<Integer,list<Integer>>> inEqnVarTplLst;
  input array<Integer> varindxs;
  input array<Integer> eqnindxs;
  input list<tuple<Integer,list<Integer>>> iAcc;
  output list<tuple<Integer,list<Integer>>> oAcc;
algorithm
  oAcc := match(inEqnVarTplLst,varindxs,eqnindxs,iAcc)
    local
      Integer e;
      list<Integer> vars;
      list<tuple<Integer,list<Integer>>> rest,acc;
    case({},_,_,_) then listReverse(iAcc);
    case((e,vars)::rest,_,_,_)
      equation
        e = eqnindxs[e];
        vars = List.map1r(vars,arrayGet,varindxs);
        acc = List.consOnTrue(intGt(e,0), (e,vars), iAcc);
      then
        updateTornSystemComp(rest,varindxs,eqnindxs,acc);
  end match;
end updateTornSystemComp;

protected function updateVarArray
" function: updateVarArray
  author: Frenkel TUD 2012-09"
  input Integer index;
  input Integer numberOfElement;
  input Integer insertindex;
  input array<Option<BackendDAE.Var>> varOptArr;
  input array<list<BackendDAE.CrefIndex>> crefIdxLstArr;
  input Integer bucketSize;
  input array<Integer> ass1 "ass[varindx]=eqnindx";
  input array<Integer> ass2 "ass[eqnindx]=varindx";
  input array<Integer> newindexarr;
  output Integer newnumberOfElement;
algorithm
  newnumberOfElement := matchcontinue(index,numberOfElement,insertindex,varOptArr,crefIdxLstArr,bucketSize,ass1,ass2,newindexarr)
    local
      BackendDAE.Var var;
      DAE.ComponentRef cr;
      Integer e,indx,i;
      list<BackendDAE.CrefIndex> indexes;
    // found element
    case(_,_,_,_,_,_,_,_,_)
      equation
        true = intLe(index,numberOfElement);
        SOME(var as BackendDAE.VAR(varName=cr)) = varOptArr[index];
        // insert on new pos
        _ = arrayUpdate(varOptArr,insertindex,SOME(var));
        // store new pos
        _ = arrayUpdate(newindexarr,index,insertindex);
        // add to hash vec
        indx = HashTable2.hashFunc(cr, bucketSize);
        indexes = crefIdxLstArr[indx + 1];
        i = insertindex-1;
        _ = arrayUpdate(crefIdxLstArr, indx + 1, (BackendDAE.CREFINDEX(cr,i) :: indexes));                
        // update assignments
        e = ass1[index];
        _ = arrayUpdate(ass1,insertindex,e);
        _ = arrayUpdate(ass2,e,insertindex);        
      then
        updateVarArray(index+1,numberOfElement,insertindex+1,varOptArr,crefIdxLstArr,bucketSize,ass1,ass2,newindexarr);
    // found non element
    case(_,_,_,_,_,_,_,_,_)
      equation
        true = intLe(index,numberOfElement);
        NONE() = varOptArr[index];
      then
        updateVarArray(index+1,numberOfElement,insertindex,varOptArr,crefIdxLstArr,bucketSize,ass1,ass2,newindexarr);
    // at the end
    case(_,_,_,_,_,_,_,_,_)
      equation
        false = intLe(index,numberOfElement);
      then
        insertindex-1;
    else
      equation
        print("BackendDAEOptimize.updateVarArray failed\n");
      then
        fail();
  end matchcontinue;
end updateVarArray;

protected function updateEquationArray
" function: updateEquationArray
  author: Frenkel TUD 2012-09"
  input Integer index;
  input Integer numberOfElement;
  input Integer insertindex;
  input array<Option<BackendDAE.Equation>> equOptArr;
  input array<Integer> ass1 "ass[varindx]=eqnindx";
  input array<Integer> ass2 "ass[eqnindx]=varindx";
  input array<Integer> newindexarr;
  output Integer newnumberOfElement;
algorithm
  newnumberOfElement := matchcontinue(index,numberOfElement,insertindex,equOptArr,ass1,ass2,newindexarr)
    local
      BackendDAE.Equation eqn;
      Integer v;
    // found element
    case(_,_,_,_,_,_,_)
      equation
        true = intLe(index,numberOfElement);
        SOME(eqn) = equOptArr[index];
        // insert on new pos
        _ = arrayUpdate(equOptArr,insertindex,SOME(eqn));
        // store new pos
        _ = arrayUpdate(newindexarr,index,insertindex);
        // update assignments
        v = ass2[index];
        _ = arrayUpdate(ass2,insertindex,v);
        _ = arrayUpdate(ass1,v,insertindex);        
      then
        updateEquationArray(index+1,numberOfElement,insertindex+1,equOptArr,ass1,ass2,newindexarr);
    // found non element
    case(_,_,_,_,_,_,_)
      equation
        true = intLe(index,numberOfElement);
        NONE() = equOptArr[index];
      then
        updateEquationArray(index+1,numberOfElement,insertindex,equOptArr,ass1,ass2,newindexarr);
    // at the end
    case(_,_,_,_,_,_,_)
      equation
        false = intLe(index,numberOfElement);
      then
        insertindex-1;
    else
      equation
        print("BackendDAEOptimize.updateEquationArray failed\n");
      then
        fail();
  end matchcontinue;
end updateEquationArray;

protected function traverseIncidenceMatrix 
" function: traverseIncidenceMatrix
  author: Frenkel TUD 2010-12"
  replaceable type Type_a subtypeof Any;
  input BackendDAE.IncidenceMatrix inM;
  input FuncType func;
  input Type_a inTypeA;
  output BackendDAE.IncidenceMatrix outM;
  output Type_a outTypeA;
  partial function FuncType
    input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix,Type_a> inTpl;
    output tuple<list<Integer>,BackendDAE.IncidenceMatrix,Type_a> outTpl;
  end FuncType;
algorithm
  (outM,outTypeA) := traverseIncidenceMatrix1(inM,func,1,arrayLength(inM),inTypeA);
end traverseIncidenceMatrix;

protected function traverseIncidenceMatrix1 
" function: traverseIncidenceMatrix1
  author: Frenkel TUD 2010-12"
  replaceable type Type_a subtypeof Any;
  input BackendDAE.IncidenceMatrix inM;
  input FuncType func;
  input Integer pos "iterated 1..len";
  input Integer len "length of array";
  input Type_a inTypeA;
  output BackendDAE.IncidenceMatrix outM;
  output Type_a outTypeA;
  partial function FuncType
    input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix,Type_a> inTpl;
    output tuple<list<Integer>,BackendDAE.IncidenceMatrix,Type_a> outTpl;
  end FuncType;
algorithm
  (outM,outTypeA) := traverseIncidenceMatrix2(inM,func,pos,len,intGt(pos,len),inTypeA);
end traverseIncidenceMatrix1;

protected function traverseIncidenceMatrix2 
" function: traverseIncidenceMatrix1
  author: Frenkel TUD 2010-12"
  replaceable type Type_a subtypeof Any;
  input BackendDAE.IncidenceMatrix inM;
  input FuncType func;
  input Integer pos "iterated 1..len";
  input Integer len "length of array";
  input Boolean stop;
  input Type_a inTypeA;
  output BackendDAE.IncidenceMatrix outM;
  output Type_a outTypeA;
  partial function FuncType
    input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix,Type_a> inTpl;
    output tuple<list<Integer>,BackendDAE.IncidenceMatrix,Type_a> outTpl;
  end FuncType;
  annotation(__OpenModelica_EarlyInline = true);
algorithm
  (outM,outTypeA) := match (inM,func,pos,len,stop,inTypeA)
    local 
      BackendDAE.IncidenceMatrix m,m1,m2;
      Type_a extArg,extArg1,extArg2;
      list<Integer> eqns,eqns1;
    
    case(_,_,_,_,true,_)
    then (inM,inTypeA);
    
    case(_,_,_,_,false,_)
      equation
        ((eqns,m,extArg)) = func((inM[pos],pos,inM,inTypeA));
        eqns1 = List.removeOnTrue(pos,intLt,eqns);
        (m1,extArg1) = traverseIncidenceMatrixList(eqns1,m,func,arrayLength(m),pos,extArg);
        (m2,extArg2) = traverseIncidenceMatrix1(m1,func,pos+1,len,extArg1);
      then (m2,extArg2);
      
  end match;
end traverseIncidenceMatrix2;

protected function traverseIncidenceMatrixList 
" function: traverseIncidenceMatrixList
  author: Frenkel TUD 2011-04"
  replaceable type Type_a subtypeof Any;
  input list<Integer> inLst "elements to traverse";
  input BackendDAE.IncidenceMatrix inM;
  input FuncType func;
  input Integer len "length of array";
  input Integer maxpos "do not go further than this position";
  input Type_a inTypeA;
  output BackendDAE.IncidenceMatrix outM;
  output Type_a outTypeA;
  partial function FuncType
    input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix,Type_a> inTpl;
    output tuple<list<Integer>,BackendDAE.IncidenceMatrix,Type_a> outTpl;
  end FuncType;
algorithm
  (outM,outTypeA) := matchcontinue(inLst,inM,func,len,maxpos,inTypeA)
    local 
      BackendDAE.IncidenceMatrix m,m1;
      Type_a extArg,extArg1;
      list<Integer> rest,eqns,eqns1,alleqns;
      Integer pos;
          
    case({},_,_,_,_,_) then (inM,inTypeA);
    
    case(pos::rest,_,_,_,_,_) equation
      // do not leave the list
      true = intLt(pos,len+1);
      // do not more than necesary
      true = intLt(pos,maxpos);
      ((eqns,m,extArg)) = func((inM[pos],pos,inM,inTypeA));
      eqns1 = List.removeOnTrue(maxpos,intLt,eqns);
      alleqns = List.unionOnTrueList({rest, eqns1},intEq);
      (m1,extArg1) = traverseIncidenceMatrixList(alleqns,m,func,len,maxpos,extArg);
    then (m1,extArg1);

    case(pos::rest,_,_,_,_,_) equation
      // do not leave the list
      true = intLt(pos,len+1);
      (m,extArg) = traverseIncidenceMatrixList(rest,inM,func,len,maxpos,inTypeA);
    then (m,extArg);
      
    case (_,_,_,_,_,_)
      equation
        Debug.fprintln(Flags.FAILTRACE, "- BackendDAEOptimize.traverseIncidenceMatrixList failed");
      then
        fail();      
  end matchcontinue;
end traverseIncidenceMatrixList;

protected function toplevelInputOrUnfixed
  input BackendDAE.Var inVar;
  output Boolean b;
algorithm
  b := BackendVariable.isVarOnTopLevelAndInput(inVar) or 
       BackendVariable.isParam(inVar) and not BackendVariable.varFixed(inVar);
end toplevelInputOrUnfixed;

protected function traversingTimeEqnsFinder "
Author: Frenkel 2010-12"
  input tuple<DAE.Exp, tuple<Boolean,BackendDAE.Variables,BackendDAE.Variables,Boolean,Boolean> > inExp;
  output tuple<DAE.Exp, Boolean, tuple<Boolean,BackendDAE.Variables,BackendDAE.Variables,Boolean,Boolean> > outExp;
algorithm 
  outExp := matchcontinue(inExp)
    local
      DAE.Exp e;
      Boolean b,b1,b2;
      BackendDAE.Variables vars,knvars;
      DAE.ComponentRef cr;
      BackendDAE.Var var;
      list<BackendDAE.Var> vlst;
    
    case((e as DAE.CREF(DAE.CREF_IDENT(ident = "time",subscriptLst = {}),_), (_,vars,knvars,b1,b2)))
      then ((e,false,(true,vars,knvars,b1,b2)));       
    // inputs not constant and parameter(fixed=false) are constant but evaluated after konstant variables are evaluted
    case((e as DAE.CREF(cr,_), (_,vars,knvars,b1,b2)))
      equation
        (vlst,_::_)= BackendVariable.getVar(cr, knvars) "input variables stored in known variables are input on top level" ;
        false = List.mapAllValueBool(vlst,toplevelInputOrUnfixed,false);
      then ((e,false,(true,vars,knvars,b1,b2)));
    case((e as DAE.CALL(path = Absyn.IDENT(name = "sample"), expLst = {_,_}), (_,vars,knvars,b1,b2))) then ((e,false,(true,vars,knvars,b1,b2)));
    case((e as DAE.CALL(path = Absyn.IDENT(name = "pre"), expLst = {_}), (_,vars,knvars,b1,b2))) then ((e,false,(true,vars,knvars,b1,b2)));
    case((e as DAE.CALL(path = Absyn.IDENT(name = "change"), expLst = {_}), (_,vars,knvars,b1,b2))) then ((e,false,(true,vars,knvars,b1,b2)));
    case((e as DAE.CALL(path = Absyn.IDENT(name = "edge"), expLst = {_}), (_,vars,knvars,b1,b2))) then ((e,false,(true,vars,knvars,b1,b2)));
    // case for finding simple equation in jacobians 
    // there are all known variables mark as input
    // and they are all time-depending  
    case((e as DAE.CREF(cr,_), (_,vars,knvars,true,b2)))
      equation
        (var::_,_::_)= BackendVariable.getVar(cr, knvars);
        DAE.INPUT() = BackendVariable.getVarDirection(var);
      then ((e,false,(true,vars,knvars,true,b2)));  
    // unkown var
    case((e as DAE.CREF(cr,_), (_,vars,knvars,b1,true)))
      equation
        (var::_,_::_)= BackendVariable.getVar(cr, vars);
      then ((e,false,(true,vars,knvars,b1,true)));          
    case((e,(b,vars,knvars,b1,b2))) then ((e,not b,(b,vars,knvars,b1,b2)));
    
  end matchcontinue;
end traversingTimeEqnsFinder;

public function countSimpleEquations
"function: countSimpleEquations
  author: Frenkel TUD 2011-05
  This function count the simple equations on the form a=b and a=const and a=f(not time)
  in BackendDAE.BackendDAE. Note this functions does not use variable replacements, because
  of this the number of simple equations is maybe smaller than using variable replacements."
  input BackendDAE.BackendDAE inDlow;
  input BackendDAE.IncidenceMatrix inM;
  output Integer outSimpleEqns;
algorithm
  outSimpleEqns:=
  match (inDlow,inM)
    local
      BackendDAE.BackendDAE dlow;
      BackendDAE.EquationArray eqns;
      Integer n;
    case (dlow,inM)
      equation
        // check equations
       (_,(_,n)) = traverseIncidenceMatrix(inM,countSimpleEquationsFinder,(dlow,0));
      then n;
  end match;
end countSimpleEquations;

protected function countSimpleEquationsFinder
"author: Frenkel TUD 2011-05"
 input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix, tuple<BackendDAE.BackendDAE,Integer>> inTpl;
 output tuple<list<Integer>,BackendDAE.IncidenceMatrix, tuple<BackendDAE.BackendDAE,Integer>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.IncidenceMatrixElement elem;
      Integer pos,l,i,n,n_1;
      BackendDAE.IncidenceMatrix m;
      BackendDAE.BackendDAE dae;
      BackendDAE.EqSystem syst;
      BackendDAE.Shared shared;
    case ((elem,pos,m,(dae as BackendDAE.DAE({syst},shared),n)))
      equation
        // check number of vars in eqns
        l = listLength(elem);
        true = intLt(l,3);
        true = intGt(l,0);
        countsimpleEquation(elem,l,pos,syst,shared);
        n_1 = n+1;
      then (({},m,(dae,n_1)));
    case ((elem,pos,m,(dae,n)))
      then (({},m,(dae,n))); 
  end matchcontinue;
end countSimpleEquationsFinder;

protected function countsimpleEquation 
" function: countsimpleEquation
  author: Frenkel TUD 2011-05"
  input BackendDAE.IncidenceMatrixElement elem;
  input Integer length;
  input Integer pos;
  input BackendDAE.EqSystem syst;
  input BackendDAE.Shared shared;
algorithm
  _ := matchcontinue(elem,length,pos,syst,shared)
    local 
      DAE.ComponentRef cr;
      Integer i,j,pos_1;
      DAE.Exp es,cre,e1,e2;
      BackendDAE.Variables vars,knvars;
      BackendDAE.Var var;
      BackendDAE.EquationArray eqns;
      BackendDAE.Equation eqn;
      Boolean negate;
      DAE.ElementSource source;
    // a = const
    // wbraun:
    // speacial case for Jacobains, since there are all known variablen
    // time depending input variables    
    case ({i},_,_,_,BackendDAE.SHARED(backendDAEType = BackendDAE.JACOBIAN()))
      equation 
        vars = BackendVariable.daeVars(syst);
        var = BackendVariable.getVarAt(vars,intAbs(i));
        // no State
        false = BackendVariable.isStateorStateDerVar(var);
        // try to solve the equation
        pos_1 = pos-1;
        eqns = BackendEquation.daeEqns(syst);
        eqn = BackendDAEUtil.equationNth(eqns,pos_1);
        BackendDAE.EQUATION(exp=e1,scalar=e2,source=source) = eqn;
        // variable time not there
        knvars = BackendVariable.daeKnVars(shared);
        ((_,(false,_,_,_,_))) = Expression.traverseExpTopDown(e1, traversingTimeEqnsFinder, (false,vars,knvars,true,false));
        ((_,(false,_,_,_,_))) = Expression.traverseExpTopDown(e2, traversingTimeEqnsFinder, (false,vars,knvars,true,false));
        cr = BackendVariable.varCref(var);
        cre = Expression.crefExp(cr);
        (_,{}) = ExpressionSolve.solve(e1,e2,cre);
      then ();              
    // a = const
    case ({i},_,_,_,_)
      equation 
        vars = BackendVariable.daeVars(syst);
        var = BackendVariable.getVarAt(vars,intAbs(i));
        // no State
        false = BackendVariable.isStateorStateDerVar(var);
        // try to solve the equation
        pos_1 = pos-1;
        eqns = BackendEquation.daeEqns(syst);
        eqn = BackendDAEUtil.equationNth(eqns,pos_1);
        BackendDAE.EQUATION(exp=e1,scalar=e2,source=source) = eqn;
        // variable time not there
        knvars = BackendVariable.daeKnVars(shared);
        ((_,(false,_,_,_,_))) = Expression.traverseExpTopDown(e1, traversingTimeEqnsFinder, (false,vars,knvars,false,false));
        ((_,(false,_,_,_,_))) = Expression.traverseExpTopDown(e2, traversingTimeEqnsFinder, (false,vars,knvars,false,false));
        cr = BackendVariable.varCref(var);
        cre = Expression.crefExp(cr);
        (_,{}) = ExpressionSolve.solve(e1,e2,cre);
      then ();
    // a = der(b) 
    case ({i,j},_,_,_,_)
      equation
        pos_1 = pos-1;
        eqns = BackendEquation.daeEqns(syst);
        eqn = BackendDAEUtil.equationNth(eqns,pos_1);
        (cr,_,_,_,_) = BackendEquation.derivativeEquation(eqn);
        // select candidate
        vars = BackendVariable.daeVars(syst);
        ((_::_),(_::_)) = BackendVariable.getVar(cr,vars);
      then ();
    // a = b 
    case ({i,j},_,_,_,_)
      equation
        pos_1 = pos-1;
        eqns = BackendEquation.daeEqns(syst);
        (eqn as BackendDAE.EQUATION(source=source)) = BackendDAEUtil.equationNth(eqns,pos_1);
        _ = BackendEquation.aliasEquation(eqn);
      then ();
  end matchcontinue;
end countsimpleEquation;


/*  
 * evalutate final parameters stuff
 *
 */ 

public function evaluateFinalParameters
"function: evaluateFinalParameters
  author Frenkel TUD"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := match (dae)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,knvars1,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl,repl1,repl2;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation
        repl = BackendVarTransform.emptyReplacements();
        (_,(repl1,_)) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,removeFinalParametersFinder,(repl,knvars));
        (knvars1,repl2) = replaceFinalVars(1,knvars,repl1,true);
        Debug.fcall(Flags.DUMP_FP_REPL, BackendVarTransform.dumpReplacements, repl2);
        systs = List.map2(systs,evaluateFinalParametersVariables,repl2,SOME(knvars1));
        (av,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(av,replaceFinalVarTraverser,(repl2,0));
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars1,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end evaluateFinalParameters;

protected function evaluateFinalParametersVariables
"function: evaluateFinalParametersVariables
  author Frenkel TUD"
  input BackendDAE.EqSystem isyst;
  input BackendVarTransform.VariableReplacements repl;
  input Option<BackendDAE.Variables> oKnvars;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,repl,oKnvars)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns;
      Option<BackendDAE.IncidenceMatrix> m;
      Option<BackendDAE.IncidenceMatrixT> mT;
      BackendDAE.Matching matching;
      BackendDAE.StateSets stateSets;
      BackendDAE.Variables knVars;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,m=m,mT=mT,matching=matching,stateSets=stateSets),_,NONE())
      equation
        (vars,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(vars,replaceFinalVarTraverser,(repl,0));
      then
        BackendDAE.EQSYSTEM(vars,eqns,m,mT,matching,stateSets);
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,m=m,mT=mT,matching=matching,stateSets=stateSets),_,SOME(knVars))
      equation
        (vars,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(vars,replaceFinalVarTraverserEvaluateFixed,(repl,0,knVars));
      then
        BackendDAE.EQSYSTEM(vars,eqns,m,mT,matching,stateSets);
  end match;
end evaluateFinalParametersVariables;

/*  
 * remove final parameters stuff
 *
 */ 
public function removeFinalParameters
"function: removeFinalParameters
  author Frenkel TUD"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := match (dae)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,knvars1,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl,repl1,repl2;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation
        repl = BackendVarTransform.emptyReplacements();
        ((repl1,_)) = BackendVariable.traverseBackendDAEVars(knvars,removeFinalParametersFinder,(repl,knvars));
        (knvars1,repl2) = replaceFinalVars(1,knvars,repl1,true);
        Debug.fcall(Flags.DUMP_FP_REPL, BackendVarTransform.dumpReplacements, repl2);
        systs = List.map1(systs,removeFinalParametersWork,repl2);
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars1,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeFinalParameters;

protected function removeFinalParametersWork
"function: removeFinalParametersWork
  author Frenkel TUD"
  input BackendDAE.EqSystem isyst;
  input BackendVarTransform.VariableReplacements repl;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,repl)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      list<BackendDAE.Equation> eqns_1,lsteqns;
      Boolean b;
      BackendDAE.EqSystem syst;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),_)
      equation
        lsteqns = BackendEquation.equationList(eqns);
        (eqns_1,b) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        eqns1 = Debug.bcallret1(b,BackendEquation.listEquation,eqns_1,eqns);
        syst = Util.if_(b,BackendDAE.EQSYSTEM(vars,eqns1,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets),isyst);
      then
        syst;
  end match;
end removeFinalParametersWork;

protected function removeFinalParametersFinder
"author: Frenkel TUD 2011-03"
 input tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,BackendDAE.Variables>> inTpl;
 output tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,BackendDAE.Variables>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Variables vars;
      BackendDAE.Var v;
      BackendVarTransform.VariableReplacements repl,repl_1;
      DAE.ComponentRef varName;
      Option< .DAE.VariableAttributes> values;
      DAE.Exp exp,exp1;
      Values.Value bindValue;
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindExp=SOME(exp),values=values),(repl,vars)))
      equation
        true = BackendVariable.isFinalVar(v);
        ((exp1, _)) = Expression.traverseExp(exp, BackendDAEUtil.replaceCrefsWithValues, (vars, varName));
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp1,NONE());
        v = BackendVariable.setBindExp(v,exp1);
      then ((v,(repl_1,vars)));
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindValue=SOME(bindValue),values=values),(repl,vars)))
      equation
        true = BackendVariable.isFinalVar(v);
        exp = ValuesUtil.valueExp(bindValue);
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp,NONE());
      then ((v,(repl_1,vars)));
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindExp=NONE(),values=values),(repl,vars)))
      equation
        true = BackendVariable.isFinalVar(v);
        exp = DAEUtil.getStartAttrFail(values);
        ((exp1, _)) = Expression.traverseExp(exp, BackendDAEUtil.replaceCrefsWithValues, (vars, varName));
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp1,NONE());
      then ((v,(repl_1,vars)));

    case _ then inTpl;
  end matchcontinue;
end removeFinalParametersFinder;

protected function replaceFinalVars
" function: replaceFinalVars
  author: Frenkel TUD 2011-04"
  input Integer inNumRepl;
  input BackendDAE.Variables inVars;
  input BackendVarTransform.VariableReplacements inRepl;
  input Boolean evaluteStart;
  output BackendDAE.Variables outVars;
  output BackendVarTransform.VariableReplacements outRepl;
algorithm
  (outVars,outRepl) := matchcontinue(inNumRepl,inVars,inRepl,evaluteStart)
    local 
      Integer numrepl;
      BackendDAE.Variables knvars,knvars1,knvars2;
      BackendVarTransform.VariableReplacements repl,repl1,repl2;
    
    case(numrepl,knvars,repl,_)
      equation
      true = intEq(0,numrepl);
    then (knvars,repl);
    
    case(numrepl,knvars,repl,false)
      equation
      (knvars1,(repl1,numrepl)) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,replaceFinalVarTraverser,(repl,0));
      (knvars2,repl2) = replaceFinalVars(numrepl,knvars1,repl1,evaluteStart);
    then (knvars2,repl2);

    case(numrepl,knvars,repl,true)
      equation
      (knvars1,(repl1,numrepl,_)) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,replaceFinalVarTraverserEvaluateFixed,(repl,0,knvars));
      (knvars2,repl2) = replaceFinalVars(numrepl,knvars1,repl1,evaluteStart);
    then (knvars2,repl2);

  end matchcontinue;
end replaceFinalVars;

protected function replaceFinalVarTraverserEvaluateFixed
" function replaceFinalVarTraverserEvaluateFixed
  author: Frenkel TUD 2011-04
  do replacements of final parameters in the variables and evaluates all fixed attributes of the variables to constant values."
 input tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,Integer,BackendDAE.Variables>> inTpl;
 output tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,Integer,BackendDAE.Variables>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v,v1;
      BackendVarTransform.VariableReplacements repl,repl_1;
      Integer numrepl;
      DAE.Exp e,e1;
      DAE.ComponentRef cr;
      Option<DAE.VariableAttributes> attr,new_attr;
      BackendDAE.Variables knvars;
      
    case ((v as BackendDAE.VAR(varName=cr,bindExp=SOME(e),values=attr),(repl,numrepl,knvars)))
      equation
        (e1,true) = BackendVarTransform.replaceExp(e, repl, NONE());
        (e1,_) = ExpressionSimplify.simplify(e1);
        v1 = BackendVariable.setBindExp(v,e1);
        repl_1 = addConstExpReplacement(e1,cr,repl);
        (attr,repl_1) = BackendDAEUtil.traverseBackendDAEVarAttr(attr,traverseExpVisitorWrapper,repl_1);
        v1 = BackendVariable.setVarAttributes(v1,attr);
        v1 = evaluateFixedAttribute(v1,knvars);
      then ((v1,(repl_1,numrepl+1,knvars)));
  
    case  ((v as BackendDAE.VAR(values=attr),(repl,numrepl,knvars)))
      equation 
        (new_attr,repl) = BackendDAEUtil.traverseBackendDAEVarAttr(attr,traverseExpVisitorWrapper,repl);
        v1 = BackendVariable.setVarAttributes(v,new_attr);
        v1 = evaluateFixedAttribute(v1,knvars);  
      then ((v1,(repl,numrepl,knvars)));
  end matchcontinue;
end replaceFinalVarTraverserEvaluateFixed;

protected function evaluateFixedAttribute
  input BackendDAE.Var inVar;
  input BackendDAE.Variables knvars;
  output BackendDAE.Var outVar;
algorithm
  outVar := matchcontinue(inVar,knvars)
    local
      DAE.ComponentRef cr;
      DAE.Exp e,e1;
      Option<DAE.VariableAttributes> attr;
      BackendDAE.Var v;
      Boolean b;
      DAE.ElementSource source;
    case (BackendDAE.VAR(varName=cr,values=attr as SOME(DAE.VAR_ATTR_REAL(fixed=SOME(e))),source=source),_)
      equation
        ((e1, (_,b,_))) = Expression.traverseExp(e, replaceCrefWithBindExp, (knvars,false,HashSet.emptyHashSet()));
        e1 = evaluateFixedAttributeReportWarning(b,cr,e,e1,source,knvars);
        (e1,_) = ExpressionSimplify.simplify(e1);
        attr = DAEUtil.setFixedAttr(attr,SOME(e1));
        v = BackendVariable.setVarAttributes(inVar,attr);
      then 
        v;
    case (BackendDAE.VAR(varName=cr,values=attr as SOME(DAE.VAR_ATTR_INT(fixed=SOME(e))),source=source),_)
      equation
        ((e1, (_,b,_))) = Expression.traverseExp(e, replaceCrefWithBindExp, (knvars,false,HashSet.emptyHashSet()));
        e1 = evaluateFixedAttributeReportWarning(b,cr,e,e1,source,knvars);
        (e1,_) = ExpressionSimplify.simplify(e1);
        attr = DAEUtil.setFixedAttr(attr,SOME(e1));
        v = BackendVariable.setVarAttributes(inVar,attr);
      then 
        v;          
    case (BackendDAE.VAR(varName=cr,values=attr as SOME(DAE.VAR_ATTR_BOOL(fixed=SOME(e))),source=source),_)
      equation
        ((e1, (_,b,_))) = Expression.traverseExp(e, replaceCrefWithBindExp, (knvars,false,HashSet.emptyHashSet()));
        e1 = evaluateFixedAttributeReportWarning(b,cr,e,e1,source,knvars);
        (e1,_) = ExpressionSimplify.simplify(e1);
        attr = DAEUtil.setFixedAttr(attr,SOME(e1));
        v = BackendVariable.setVarAttributes(inVar,attr);
      then 
        v;          
    case (BackendDAE.VAR(varName=cr,values=attr as SOME(DAE.VAR_ATTR_ENUMERATION(fixed=SOME(e))),source=source),_)
      equation
        ((e1, (_,b,_))) = Expression.traverseExp(e, replaceCrefWithBindExp, (knvars,false,HashSet.emptyHashSet()));
        e1 = evaluateFixedAttributeReportWarning(b,cr,e,e1,source,knvars);
        (e1,_) = ExpressionSimplify.simplify(e1);
        attr = DAEUtil.setFixedAttr(attr,SOME(e1));
        v = BackendVariable.setVarAttributes(inVar,attr);
      then 
        v;
    case (_,_) then inVar;
  end matchcontinue;
end evaluateFixedAttribute;

protected function evaluateFixedAttributeReportWarning
  input Boolean b;
  input DAE.ComponentRef cr;
  input DAE.Exp e;
  input DAE.Exp e1;
  input DAE.ElementSource source;
  input BackendDAE.Variables knvars;
  output DAE.Exp outE;
algorithm
  outE := match(b,cr,e,e1,source,knvars)
    local
      Absyn.Info info;
      String msg;
      DAE.Exp e2;
    case (false,_,_,_,_,_) then e1;
    case (true,_,_,_,_,_)
      equation
        info = DAEUtil.getElementSourceFileInfo(source);
        ((e2, (_,_,_))) = Expression.traverseExp(e1, replaceCrefWithBindStartExp, (knvars,false,HashSet.emptyHashSet()));
        msg = ComponentReference.printComponentRefStr(cr) +& " has unevaluateable fixed attribute value \"" +& ExpressionDump.printExpStr(e) +& "\" use values from start attribute(s) \"" +& ExpressionDump.printExpStr(e2) +& "\"";
        Error.addSourceMessage(Error.COMPILER_WARNING, {msg}, info);
      then
        e2;
  end match;
end evaluateFixedAttributeReportWarning;

protected function replaceCrefWithBindExp
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean,HashSet.HashSet>> inTuple;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean,HashSet.HashSet>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e;
      BackendDAE.Variables vars;
      DAE.ComponentRef cr;
      Boolean b;
      HashSet.HashSet hs;
    // true if crefs replaced in expression
    case ((DAE.CREF(componentRef=cr), (vars,b,hs)))
      equation
        // check for cyclic bindings in start value
        false = BaseHashSet.has(cr, hs);
        ({BackendDAE.VAR(bindExp = SOME(e))}, _) = BackendVariable.getVar(cr, vars);
        hs = BaseHashSet.add(cr,hs);
        ((e, (_,b,hs))) = Expression.traverseExp(e, replaceCrefWithBindExp, (vars,b,hs));
      then
        ((e, (vars,b,hs)));
    // true if crefs in expression
    case ((e as DAE.CREF(componentRef=cr), (vars,_,hs)))
      then
        ((e, (vars,true,hs)));        
    else then inTuple;
  end matchcontinue;
end replaceCrefWithBindExp;

protected function replaceCrefWithBindStartExp
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean,HashSet.HashSet>> inTuple;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean,HashSet.HashSet>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e;
      BackendDAE.Var v;
      BackendDAE.Variables vars;
      DAE.ComponentRef cr;
      Boolean b;
      HashSet.HashSet hs;
    // true if crefs replaced in expression
    case ((DAE.CREF(componentRef=cr), (vars,b,hs)))
      equation
        // check for cyclic bindings in start value
        false = BaseHashSet.has(cr, hs);
        ({v}, _) = BackendVariable.getVar(cr, vars);
        e = BackendVariable.varStartValueType(v);
        hs = BaseHashSet.add(cr,hs);
        ((e, (_,b,hs))) = Expression.traverseExp(e, replaceCrefWithBindExp, (vars,b,hs));
      then
        ((e, (vars,b,hs)));
    // true if crefs in expression
    case ((e as DAE.CREF(componentRef=cr), (vars,_,hs)))
      then
        ((e, (vars,true,hs)));        
    else then inTuple;
  end matchcontinue;
end replaceCrefWithBindStartExp;

protected function replaceFinalVarTraverser
"author: Frenkel TUD 2011-04"
 input tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,Integer>> inTpl;
 output tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,Integer>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v,v1;
      BackendVarTransform.VariableReplacements repl,repl_1;
      Integer numrepl;
      DAE.Exp e,e1;
      DAE.ComponentRef cr;
      Option<DAE.VariableAttributes> attr,new_attr;
      
    case ((v as BackendDAE.VAR(varName=cr,bindExp=SOME(e),values=attr),(repl,numrepl)))
      equation
        (e1,true) = BackendVarTransform.replaceExp(e, repl, NONE());
        (e1,_) = ExpressionSimplify.simplify(e1);
        v1 = BackendVariable.setBindExp(v,e1);
        repl_1 = addConstExpReplacement(e1,cr,repl);
        (attr,repl_1) = BackendDAEUtil.traverseBackendDAEVarAttr(attr,traverseExpVisitorWrapper,repl_1);
        v1 = BackendVariable.setVarAttributes(v1,attr);
      then ((v1,(repl_1,numrepl+1)));
  
    case  ((v as BackendDAE.VAR(values=attr),(repl,numrepl)))
      equation 
        (new_attr,repl) = BackendDAEUtil.traverseBackendDAEVarAttr(attr,traverseExpVisitorWrapper,repl);
        v1 = BackendVariable.setVarAttributes(v,new_attr);      
      then ((v1,(repl,numrepl)));
  end matchcontinue;
end replaceFinalVarTraverser;

protected function addConstExpReplacement
  input DAE.Exp inExp;
  input DAE.ComponentRef cr;
  input BackendVarTransform.VariableReplacements inRepl;
  output BackendVarTransform.VariableReplacements outRepl;
algorithm
  outRepl := matchcontinue(inExp,cr,inRepl)
    case (_,_,_)
      equation
        true = Expression.isConst(inExp);
      then
        BackendVarTransform.addReplacement(inRepl, cr, inExp,NONE());
    else
      inRepl;
  end matchcontinue;
end addConstExpReplacement;

protected function traverseExpVisitorWrapper "help function to replaceFinalVarTraverser"
  input tuple<DAE.Exp,BackendVarTransform.VariableReplacements> inTpl;
  output tuple<DAE.Exp,BackendVarTransform.VariableReplacements> outTpl;
algorithm
  outTpl := matchcontinue(inTpl)
  local 
    DAE.Exp exp;
    BackendVarTransform.VariableReplacements repl;
    DAE.ComponentRef cr;
    
    case((exp as DAE.CREF(cr,_),repl)) equation
      (exp,_) = BackendVarTransform.replaceExp(exp,repl,NONE());      
    then ((exp,repl));
    
    case _ then inTpl;
  end matchcontinue;
end traverseExpVisitorWrapper;




/*  
 * remove parameters stuff
 *
 */
public function removeParameters
"function: removeParameters
  author wbraun"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (inDAE)
    local
      BackendDAE.Variables knvars,exobj,knvars1,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcs;
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl,repl1,repl2;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation      
        repl = BackendVarTransform.emptyReplacements();
        ((repl1,_)) = BackendVariable.traverseBackendDAEVars(knvars,removeParametersFinder,(repl,knvars));
        (knvars1,repl2) = replaceFinalVars(1,knvars,repl1,false);
        (knvars1,repl2) = replaceFinalVars(1,knvars1,repl2,false);
        Debug.fcall(Flags.DUMP_PARAM_REPL, BackendVarTransform.dumpReplacements, repl2);
        systs= List.map1(systs,removeParameterswork,repl2);
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars1,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeParameters;

protected function removeParameterswork
"function: removeParameterswork
  author wbraun"
  input BackendDAE.EqSystem isyst;
  input BackendVarTransform.VariableReplacements repl;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,repl)
    local
      Option<BackendDAE.IncidenceMatrix> m,mT;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      list<BackendDAE.Equation> eqns_1,lsteqns;
      BackendDAE.Matching matching;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(vars,eqns,m,mT,matching,stateSets),_)
      equation      
        lsteqns = BackendEquation.equationList(eqns);
        (vars,_) = replaceFinalVars(1,vars,repl,false); // replacing variable attributes (e.g start) in unknown vars 
        (eqns_1,_) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        eqns1 = BackendEquation.listEquation(eqns_1);
      then
        BackendDAE.EQSYSTEM(vars,eqns1,NONE(),NONE(),matching,stateSets);
  end match;
end removeParameterswork;

protected function removeParametersFinder
"author: Frenkel TUD 2011-03"
 input tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,BackendDAE.Variables>> inTpl;
 output tuple<BackendDAE.Var, tuple<BackendVarTransform.VariableReplacements,BackendDAE.Variables>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Variables vars;
      BackendDAE.Var v;
      BackendVarTransform.VariableReplacements repl,repl_1;
      DAE.ComponentRef varName;
      Option< .DAE.VariableAttributes> values;
      DAE.Exp exp,exp1;
      Values.Value bindValue;
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindExp=SOME(exp),values=values),(repl,vars)))
      equation
        ((exp1, _)) = Expression.traverseExp(exp, BackendDAEUtil.replaceCrefsWithValues, (vars, varName));
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp1,NONE());
      then ((v,(repl_1,vars)));
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindValue=SOME(bindValue),values=values),(repl,vars)))
      equation
        exp = ValuesUtil.valueExp(bindValue);
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp,NONE());
      then ((v,(repl_1,vars)));
    case _ then inTpl;
  end matchcontinue;
end removeParametersFinder;




/*
 * remove protected parameters stuff
 *
 */
public function removeProtectedParameters
"function: removeProtectedParameters
  author Frenkel TUD"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (inDAE)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl,repl1;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation      
        repl = BackendVarTransform.emptyReplacements();
        repl1 = BackendVariable.traverseBackendDAEVars(knvars,protectedParametersFinder,repl);
        Debug.fcall(Flags.DUMP_PP_REPL, BackendVarTransform.dumpReplacements, repl1);
        systs = List.map1(systs,removeProtectedParameterswork,repl1);
      then
        (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)));
  end match;
end removeProtectedParameters;

protected function removeProtectedParameterswork
"function: removeProtectedParameterswork
  author Frenkel TUD"
  input BackendDAE.EqSystem isyst;
  input BackendVarTransform.VariableReplacements repl;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,repl)
    local
      BackendDAE.EqSystem syst;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      list<BackendDAE.Equation> eqns_1,lsteqns;
      Boolean b;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),_)
      equation      
        lsteqns = BackendEquation.equationList(eqns);
        (eqns_1,b) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        eqns1 = Debug.bcallret1(b, BackendEquation.listEquation,eqns_1,eqns);
        syst = Util.if_(b,BackendDAE.EQSYSTEM(vars,eqns1,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets),isyst);
      then
        syst;
  end match;
end removeProtectedParameterswork;

protected function protectedParametersFinder
"author: Frenkel TUD 2011-03"
 input tuple<BackendDAE.Var, BackendVarTransform.VariableReplacements> inTpl;
 output tuple<BackendDAE.Var, BackendVarTransform.VariableReplacements> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v;
      BackendVarTransform.VariableReplacements repl,repl_1;
      DAE.ComponentRef varName;
      Option< .DAE.VariableAttributes> values;
      DAE.Exp exp;
      Values.Value bindValue;
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindExp=SOME(exp),values=values),repl))
      equation
        true = DAEUtil.getProtectedAttr(values);
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp,NONE());
      then ((v,repl_1));
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.PARAM(),bindValue=SOME(bindValue),values=values),repl))
      equation
        true = DAEUtil.getProtectedAttr(values);
        true = BackendVariable.varFixed(v);
        exp = ValuesUtil.valueExp(bindValue);
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp,NONE());
      then ((v,repl_1));
    case _ then inTpl;
  end matchcontinue;
end protectedParametersFinder;




/*  
 * evaluate parameters stuff 
 * evaluate all parameter with evaluate=true Annotation
 */

public function evaluateParameters
"function: evaluateParameters
  author Frenkel TUD"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (inDAE)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
      BackendDAE.Shared shared;
      list<list<Integer>> comps,mlst;
      array<Integer> v;
      Integer size;
      BackendDAE.IncidenceMatrix m;
      BackendDAE.IncidenceMatrixT mt;
    case (BackendDAE.DAE(systs,shared as BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation     
        // sort parameters
        size = BackendVariable.varsSize(knvars);
        ((_,_,mlst,mt)) = BackendVariable.traverseBackendDAEVars(knvars,getParameterIncidenceMatrix,(knvars,1,{},arrayCreate(size,{})));
        v = listArray(List.intRange(size));
        m = listArray(listReverse(mlst));
        comps = BackendDAETransform.tarjanAlgorithm(m, mt, v, v);        
        // evaluate vars with bind expression consists of evaluated vars
        (knvars,repl,cache) = traverseVariablesSorted(comps,knvars,BackendVarTransform.emptyReplacements(),BackendVarTransform.emptyReplacements(),cache,env);
        Debug.fcall(Flags.DUMP_EA_REPL, BackendVarTransform.dumpReplacements, repl);
        systs = List.map2(systs,evaluateFinalParametersVariables,repl,NONE());
        (knvars,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,replaceFinalVarTraverser,(repl,0));
        (av,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(av,replaceFinalVarTraverser,(repl,0));
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end evaluateParameters;

/*  
 * remove evaluated parameters stuff 
 * remove all parameter with evaluate=true Annotation
 */

public function removeevaluateParameters
"function: removeevaluateParameters
  author Frenkel TUD"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (inDAE)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl;
      BackendDAE.BackendDAEType btp;
      list<BackendDAE.Equation> eqnslst;
      BackendDAE.EqSystems systs;
      BackendDAE.Shared shared;
      list<list<Integer>> comps,mlst;
      array<Integer> v;
      Integer size;
      BackendDAE.IncidenceMatrix m;
      BackendDAE.IncidenceMatrixT mt;
      Boolean b;
    case (BackendDAE.DAE(systs,shared as BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation     
        // sort parameters
        size = BackendVariable.varsSize(knvars);
        ((_,_,mlst,mt)) = BackendVariable.traverseBackendDAEVars(knvars,getParameterIncidenceMatrix,(knvars,1,{},arrayCreate(size,{})));
        v = listArray(List.intRange(size));
        m = listArray(listReverse(mlst));
        comps = BackendDAETransform.tarjanAlgorithm(m, mt, v, v);        
        // evaluate vars with bind expression consists of evaluated vars
        (knvars,repl,cache) = traverseVariablesSorted(comps,knvars,BackendVarTransform.emptyReplacements(),BackendVarTransform.emptyReplacements(),cache,env);
        Debug.fcall(Flags.DUMP_EA_REPL, BackendVarTransform.dumpReplacements, repl);
        // do replacements in initial equations
        eqnslst = BackendEquation.equationList(inieqns);
        (eqnslst,b) = BackendVarTransform.replaceEquations(eqnslst, repl,NONE());
        inieqns = Debug.bcallret1(b,BackendEquation.listEquation,eqnslst,inieqns);
        // do replacements in simple equations
        eqnslst = BackendEquation.equationList(remeqns);
        (eqnslst,b) = BackendVarTransform.replaceEquations(eqnslst, repl,NONE());
        remeqns = Debug.bcallret1(b,BackendEquation.listEquation,eqnslst,remeqns);
        // do replacements in systems        
        systs = List.map1(systs,removeProtectedParameterswork,repl);
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeevaluateParameters;

protected function traverseVariablesSorted
  input list<list<Integer>> inComps;
  input BackendDAE.Variables inKnVars;
  input BackendVarTransform.VariableReplacements repl;
  input BackendVarTransform.VariableReplacements replEvaluate;
  input Env.Cache iCache;
  input Env.Env env; 
  output BackendDAE.Variables oKnVars;
  output BackendVarTransform.VariableReplacements oReplEvaluate;
  output Env.Cache oCache;
algorithm
  (oKnVars,oReplEvaluate,oCache) := matchcontinue(inComps,inKnVars,repl,replEvaluate,iCache,env)
    local
      BackendDAE.Variables knvars;
      BackendDAE.Var v;
      BackendVarTransform.VariableReplacements repl1,evrepl;
      String str;  
      Integer c;
      list<list<Integer>> rest;
      Env.Cache cache;
      list<DAE.ComponentRef> crlst;
      list<Integer> ilst;
      list<BackendDAE.Var> vlst;
      
    case({},_,_,_,_,_)
      then
        (inKnVars,replEvaluate,iCache);
    case({c}::rest,_,_,_,_,_)
      equation
        v = BackendVariable.getVarAt(inKnVars,c);
        (knvars,cache,repl1,evrepl) = evaluateParameterBindings(v,c,inKnVars,repl,replEvaluate,iCache,env);
        (knvars,repl1,cache) =  traverseVariablesSorted(rest,knvars,repl1,evrepl,cache,env);
      then
        (knvars,repl1,cache);
    case (ilst::rest,_,_,_,_,_)
      equation
        vlst = List.map1r(ilst,BackendVariable.getVarAt,inKnVars);
        crlst = List.map(vlst,BackendVariable.varCref); 
        str = stringDelimitList(List.map(crlst,ComponentReference.printComponentRefStr),"\n");  
        str = stringAppendList({"BackendDAEOptimize.traverseVariablesSorted faild because of strong connected Block in Parameters!\n",str,"\n"});
        Error.addMessage(Error.INTERNAL_ERROR, {str});
      then
        fail();
  end matchcontinue;
end traverseVariablesSorted;


protected function evaluateParameterBindings
  input BackendDAE.Var var;
  input Integer index;
  input BackendDAE.Variables inKnVars;
  input BackendVarTransform.VariableReplacements irepl;
  input BackendVarTransform.VariableReplacements ireplEvaluate;
  input Env.Cache iCache;
  input Env.Env env; 
  output BackendDAE.Variables oKnVars;
  output Env.Cache oCache;  
  output BackendVarTransform.VariableReplacements orepl;
  output BackendVarTransform.VariableReplacements oreplEvaluate;
algorithm
  (oKnVars,oCache,orepl,oreplEvaluate) := matchcontinue(var,index,inKnVars,irepl,ireplEvaluate,iCache,env)
    local
      BackendDAE.Var v;
      DAE.ComponentRef cr;
      DAE.Exp e,e1;
      Option<DAE.VariableAttributes> dae_var_attr;
      BackendVarTransform.VariableReplacements repl,repl1;
      SCode.Comment comment;
      Env.Cache cache;
      Values.Value value;
      BackendDAE.Variables knvars;
      Boolean b;
    // Parameter with evaluate=true
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),bindExp=SOME(e),comment=SOME(comment)),_,_,_,_,_,_)
      equation
        true = hasEvaluateAnnotation(comment);  
        // applay replacements
        (e,_) = BackendVarTransform.replaceExp(e, irepl, NONE());
        // evaluate expression
        (cache, value,_) = Ceval.ceval(iCache, env, e, false,NONE(),Ceval.NO_MSG());
        e1 = ValuesUtil.valueExp(value);
        // set bind value
        v = BackendVariable.setBindExp(var,e1);
        v = BackendVariable.setVarFinal(v, true);
        // update Vararray
        knvars = BackendVariable.addVar(v, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
        repl1 = BackendVarTransform.addReplacement(ireplEvaluate, cr, e1,NONE());
      then 
        (knvars,cache,repl,repl1);
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),values=dae_var_attr,comment=SOME(comment)),_,_,_,_,_,_)
      equation
        true = hasEvaluateAnnotation(comment);
        e = DAEUtil.getStartAttrFail(dae_var_attr);
        // applay replacements
        (e,_) = BackendVarTransform.replaceExp(e, irepl, NONE());
        // evaluate expression
        (cache, value,_) = Ceval.ceval(iCache, env, e, false,NONE(),Ceval.NO_MSG());
        e1 = ValuesUtil.valueExp(value);
        // set bind value
        v = BackendVariable.setVarStartValue(var,e1);
        v = BackendVariable.setVarFinal(v, true);
        // update Vararray
        knvars = BackendVariable.addVar(v, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
        repl1 = BackendVarTransform.addReplacement(ireplEvaluate, cr, e1,NONE());         
      then 
        (knvars,cache,repl,repl1);
    // Parameter with bind expression uses only paramter with evaluate=true
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),bindExp=SOME(e)),_,_,_,_,_,_)
      equation
        // applay replacements
        (e,true) = BackendVarTransform.replaceExp(e, ireplEvaluate, NONE());
        false = Expression.expHasCrefs(e);
        // evaluate expression
        (cache, value,_) = Ceval.ceval(iCache, env, e, false,NONE(),Ceval.NO_MSG());
        e1 = ValuesUtil.valueExp(value);
        // set bind value
        v = BackendVariable.setBindExp(var,e1);
        v = BackendVariable.setVarFinal(v, true);
        // update Vararray
        knvars = BackendVariable.addVar(v, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
        repl1 = BackendVarTransform.addReplacement(ireplEvaluate, cr, e1,NONE());         
      then 
        (knvars,cache,repl,repl1);
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),values=dae_var_attr),_,_,_,_,_,_)
      equation
        e = DAEUtil.getStartAttrFail(dae_var_attr);
        // applay replacements
        (e,true) = BackendVarTransform.replaceExp(e, ireplEvaluate, NONE());
        false = Expression.expHasCrefs(e);
        // evaluate expression
        (cache, value,_) = Ceval.ceval(iCache, env, e, false,NONE(),Ceval.NO_MSG());
        e1 = ValuesUtil.valueExp(value);
        // set bind value
        v = BackendVariable.setVarStartValue(var,e1);
        v = BackendVariable.setVarFinal(v, true);
        // update Vararray
        knvars = BackendVariable.addVar(v, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
        repl1 = BackendVarTransform.addReplacement(ireplEvaluate, cr, e1,NONE());         
      then 
        (knvars,cache,repl,repl1);      
    // all other paramter
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),bindExp=SOME(e)),_,_,_,_,_,_)
      equation
        // applay replacements
        (e,b) = BackendVarTransform.replaceExp(e, ireplEvaluate, NONE());   
        (e,_) = ExpressionSimplify.condsimplify(b, e);
        // set bind value
        v = Debug.bcallret2(b, BackendVariable.setVarStartValue, var,e, var);
        // update Vararray
        knvars = Debug.bcallret2(b, BackendVariable.addVar, v, inKnVars, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
      then 
        (knvars,iCache,repl,ireplEvaluate);
    case (BackendDAE.VAR(varName = cr,varKind=BackendDAE.PARAM(),values=dae_var_attr),_,_,_,_,_,_)
      equation
        e = DAEUtil.getStartAttrFail(dae_var_attr);
        // applay replacements
        (e,b) = BackendVarTransform.replaceExp(e, ireplEvaluate, NONE());   
        (e,_) = ExpressionSimplify.condsimplify(b, e);
        // set bind value
        v = Debug.bcallret2(b, BackendVariable.setVarStartValue, var,e, var);
        // update Vararray
        knvars = Debug.bcallret2(b, BackendVariable.addVar, v, inKnVars, inKnVars);
        // save replacement
        repl = BackendVarTransform.addReplacement(irepl, cr, e,NONE());
      then 
        (knvars,iCache,repl,ireplEvaluate);
    // other vars
    else 
      (inKnVars,iCache,irepl,ireplEvaluate);
  end matchcontinue;
end evaluateParameterBindings;

protected function getParameterIncidenceMatrix
  input tuple<BackendDAE.Var,tuple<BackendDAE.Variables,Integer,list<list<Integer>>,BackendDAE.IncidenceMatrixT>> inTp;
  output tuple<BackendDAE.Var,tuple<BackendDAE.Variables,Integer,list<list<Integer>>,BackendDAE.IncidenceMatrixT>> outTpl;
algorithm
  outTpl := matchcontinue (inTp)
    local
      BackendDAE.Variables knvars;
      BackendDAE.Var v;
      DAE.Exp e;
      Option<DAE.VariableAttributes> dae_var_attr;
      list<Integer> ilst;
      Integer index;
      list<list<Integer>> m;
      BackendDAE.IncidenceMatrixT mt;

    case ((v as BackendDAE.VAR(varKind=BackendDAE.PARAM(),bindExp=SOME(e)),(knvars,index,m,mt)))
      equation
         ((_,(_,ilst))) = Expression.traverseExpTopDown(e, BackendDAEUtil.traversingincidenceRowExpFinder, (knvars,{}));
         ilst = index::ilst;
         mt = List.fold1(ilst,Util.arrayCons,index,mt);
      then 
        ((v,(knvars,index+1,ilst::m,mt)));

    case ((v as BackendDAE.VAR(varKind=BackendDAE.PARAM(),values=dae_var_attr),(knvars,index,m,mt)))
      equation
        e = DAEUtil.getStartAttrFail(dae_var_attr);
        ((_,(_,ilst))) = Expression.traverseExpTopDown(e, BackendDAEUtil.traversingincidenceRowExpFinder, (knvars,{}));
        ilst = index::ilst;
        mt = List.fold1(ilst,Util.arrayCons,index,mt);
      then 
        ((v,(knvars,index+1,ilst::m,mt)));

    case ((v,(knvars,index,m,mt)))
      equation
        ilst = {index};
        mt = arrayUpdate(mt,index,ilst);
      then 
        ((v,(knvars,index+1,ilst::m,mt)));
  end matchcontinue;
end getParameterIncidenceMatrix;

protected function hasEvaluateAnnotation
  input SCode.Comment comment;
  output Boolean b;
algorithm
  b := match(comment)
    local
      SCode.Annotation anno;
      list<SCode.Annotation> annos;
    case (SCode.COMMENT(annotation_=SOME(anno)))
      then
        SCode.hasBooleanNamedAnnotation({anno},"Evaluate");
    case(SCode.CLASS_COMMENT(annotations=annos))
      then 
        SCode.hasBooleanNamedAnnotation(annos,"Evaluate");
    else then false;
  end match;
end hasEvaluateAnnotation;



/* 
 * remove equal function calls equations stuff
 *
 */
public function removeEqualFunctionCalls
"function: removeEqualFunctionCalls
  author: Frenkel TUD 2011-04
  This function detect equal function call on the form a=f(b) and c=f(b) 
  in BackendDAE.BackendDAE to get speed up"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := BackendDAEUtil.mapEqSystem(dae,removeEqualFunctionCallsWork);
end removeEqualFunctionCalls;

protected function removeEqualFunctionCallsWork
"function: removeEqualFunctionCalls
  author: Frenkel TUD 2011-04
  This function detect equal function call on the form a=f(b) and c=f(b) 
  in BackendDAE.BackendDAE to get speed up"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
algorithm
  (osyst,oshared) := match (isyst,ishared)
    local
      BackendDAE.IncidenceMatrix m,m_1;
      BackendDAE.IncidenceMatrixT mT,mT_1;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      list<Integer> changed;
      Boolean b;
      BackendDAE.EqSystem syst;
      BackendDAE.Shared shared;
      BackendDAE.StateSets stateSets;

    case (syst as BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),shared)
      equation
        (syst,m,mT) = BackendDAEUtil.getIncidenceMatrixfromOption(syst,BackendDAE.NORMAL());
        // check equations
        (m_1,(mT_1,_,eqns1,changed)) = traverseIncidenceMatrix(m,removeEqualFunctionCallFinder,(mT,vars,eqns,{}));
        b = intGt(listLength(changed),0);
        // update arrayeqns and algorithms, collect info for wrappers
        syst = BackendDAE.EQSYSTEM(vars,eqns,SOME(m_1),SOME(mT_1),BackendDAE.NO_MATCHING(),stateSets);
        syst = BackendDAEUtil.updateIncidenceMatrix(syst,changed);
      then (syst,shared);
  end match;
end removeEqualFunctionCallsWork;

protected function removeEqualFunctionCallFinder
"author: Frenkel TUD 2010-12"
 input tuple<BackendDAE.IncidenceMatrixElement,Integer,BackendDAE.IncidenceMatrix, tuple<BackendDAE.IncidenceMatrixT,BackendDAE.Variables,BackendDAE.EquationArray,list<Integer>>> inTpl;
 output tuple<list<Integer>,BackendDAE.IncidenceMatrix, tuple<BackendDAE.IncidenceMatrixT,BackendDAE.Variables,BackendDAE.EquationArray,list<Integer>>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.IncidenceMatrixElement elem;
      Integer pos,pos_1;
      BackendDAE.IncidenceMatrix m,mT;
      list<Integer> changed;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      DAE.Exp exp,e1,e2,ecr;
      list<Integer> expvars,controleqns,expvars1;
      list<list<Integer>> expvarseqns;
      
    case ((elem,pos,m,(mT,vars,eqns,changed)))
      equation
        // check number of vars in eqns
        _::_ = elem;
        pos_1 = pos-1;
        BackendDAE.EQUATION(exp=e1,scalar=e2) = BackendDAEUtil.equationNth(eqns,pos_1);
        // BackendDump.debugStrExpStrExpStr(("Test ",e1," = ",e2,"\n"));
        (ecr,exp) = functionCallEqn(e1,e2,vars);
        // TODO: Handle this with alias-equations instead?; at least they don't replace back to the original expression...
        // failure(DAE.CREF(componentRef=_) = exp);
        // failure(DAE.UNARY(operator=DAE.UMINUS(ty=_),exp=DAE.CREF(componentRef=_)) = exp);
        // BackendDump.debugStrExpStrExpStr(("Found ",ecr," = ",exp,"\n"));
        expvars = BackendDAEUtil.incidenceRowExp(exp,vars, {},BackendDAE.NORMAL());
        // print("expvars "); BackendDump.debuglst((expvars,intString," ","\n"));
        (expvars1::expvarseqns) = List.map1(expvars,varEqns,(pos,mT));
        // print("expvars1 "); BackendDump.debuglst((expvars1,intString," ","\n"));;
        controleqns = getControlEqns(expvars1,expvarseqns);
        // print("controleqns "); BackendDump.debuglst((controleqns,intString," ","\n"));
        (eqns1,changed) = removeEqualFunctionCall(controleqns,ecr,exp,eqns,changed);
        //print("changed1 "); BackendDump.debuglst((changed1,intString," ","\n"));
        //print("changed2 "); BackendDump.debuglst((changed2,intString," ","\n"));
        // print("Next\n");
      then (({},m,(mT,vars,eqns1,changed)));
    case ((elem,pos,m,(mT,vars,eqns,changed)))
      then (({},m,(mT,vars,eqns,changed))); 
  end matchcontinue;
end removeEqualFunctionCallFinder;

protected function functionCallEqn
"function functionCallEqn
  author Frenkel TUD 2011-04"
  input DAE.Exp ie1;
  input DAE.Exp ie2;
  input BackendDAE.Variables inVars;
  output DAE.Exp outECr;
  output DAE.Exp outExp;
algorithm
  (outECr,outExp) := match (ie1,ie2,inVars)
      local
        DAE.ComponentRef cr;
        DAE.Exp e1,e2;
        DAE.Operator op;
        
      case (e1 as DAE.CREF(componentRef = cr),DAE.UNARY(operator=op as DAE.UMINUS(ty=_),exp=DAE.CREF(componentRef = _)),_)
        then fail();
      case (e1 as DAE.CREF(componentRef = cr),DAE.CREF(componentRef = _),_)
        then fail();
      case (DAE.UNARY(operator=op as DAE.UMINUS(ty=_),exp=e1 as DAE.CREF(componentRef = cr)),DAE.CREF(componentRef = _),_)
        then fail();
      // a = -f(...);
      case (e1 as DAE.CREF(componentRef = cr),DAE.UNARY(operator=op as DAE.UMINUS(ty=_),exp=e2),_)
        equation
          ((_::_),(_::_)) = BackendVariable.getVar(cr,inVars);
        then (DAE.UNARY(op,e1),e2);
      // a = f(...);
      case (e1 as DAE.CREF(componentRef = cr),e2,_)
        equation
          ((_::_),(_::_)) = BackendVariable.getVar(cr,inVars);
        then (e1,e2);
      // a = -f(...);
      case (DAE.UNARY(operator=op as DAE.UMINUS(ty=_),exp=e1),e2 as DAE.CREF(componentRef = cr),_)
        equation
          ((_::_),(_::_)) = BackendVariable.getVar(cr,inVars);
        then (DAE.UNARY(op,e2),e1);
      // f(...)=a;
      case (e1,e2 as DAE.CREF(componentRef = cr),_)
        equation
          ((_::_),(_::_)) = BackendVariable.getVar(cr,inVars);
        then (e2,e1);
  end match;
end functionCallEqn;

protected function varEqns
"function varEqns
  author Frenkel TUD 2011-04"
  input Integer v;
  input tuple<Integer,BackendDAE.IncidenceMatrixT> inTpl;
  output list<Integer> outVarEqns;
protected
  Integer pos;
  list<Integer> vareqns,vareqns1;
  BackendDAE.IncidenceMatrix mT;
algorithm
  pos := Util.tuple21(inTpl);
  mT := Util.tuple22(inTpl);
  vareqns := mT[intAbs(v)];
  vareqns1 := List.map(vareqns, intAbs);
  outVarEqns := List.removeOnTrue(intAbs(pos),intEq,vareqns1);
end varEqns;

protected function getControlEqns
"function getControlEqns
  author Frenkel TUD 2011-04"
  input list<Integer> inVarsEqn;
  input list<list<Integer>> inVarsEqns;
  output list<Integer> outEqns;
algorithm
  outEqns := match(inVarsEqn,inVarsEqns)
    local  
      list<Integer> a,b,c,d;
      list<list<Integer>> rest;
    case (a,{}) then a;
    case (a,b::rest)
      equation 
       c = List.intersectionOnTrue(a,b,intEq);
       d = getControlEqns(c,rest);
      then d;  
  end match;  
end getControlEqns;

protected function removeEqualFunctionCall
"function removeEqualFunctionCall
  author: Frenkel TUD 2011-04"
  input list<Integer> inEqsLst;
  input DAE.Exp inExp;
  input DAE.Exp inECr;
  input BackendDAE.EquationArray inEqns;
  input list<Integer> ichanged;
  output BackendDAE.EquationArray outEqns;
  output list<Integer> outEqsLst;
algorithm
  (outEqns,outEqsLst):=
  matchcontinue (inEqsLst,inExp,inECr,inEqns,ichanged)
    local
      BackendDAE.EquationArray eqns;
      BackendDAE.Equation eqn,eqn1;
      Integer pos,pos_1,i;
      list<Integer> rest,changed;
    case ({},_,_,_,_) then (inEqns,ichanged);
    case (pos::rest,_,_,_,_)
      equation
        pos_1 = pos-1;
        eqn = BackendDAEUtil.equationNth(inEqns,pos_1);
        //BackendDump.printEquationList({eqn});
        //BackendDump.debugStrExpStrExpStr(("Repalce ",inExp," with ",inECr,"\n"));
        (eqn1,(_,_,i)) = BackendDAETransform.traverseBackendDAEExpsEqnWithSymbolicOperation(eqn, replaceExp, (inECr,inExp,0));
        //BackendDump.printEquationList({eqn1});
        //print("i="); print(intString(i)); print("\n");
        true = intGt(i,0);
        eqns =  BackendEquation.equationSetnth(inEqns,pos_1,eqn1);
        changed = List.consOnTrue(not listMember(pos,ichanged),pos,ichanged);
        (eqns,changed) = removeEqualFunctionCall(rest,inExp,inECr,eqns,changed);
      then (eqns,changed);
    case (pos::rest,_,_,_,_)
      equation
        (eqns,changed) = removeEqualFunctionCall(rest,inExp,inECr,inEqns,ichanged);
      then (eqns,changed);
  end matchcontinue;      
end removeEqualFunctionCall;

public function replaceExp
"function: replaceExp
  author: Frenkel TUD"
  input tuple<DAE.Exp,tuple<list<DAE.SymbolicOperation>,tuple<DAE.Exp,DAE.Exp,Integer>>> inTpl;
  output tuple<DAE.Exp,tuple<list<DAE.SymbolicOperation>,tuple<DAE.Exp,DAE.Exp,Integer>>> outTpl;
protected
  DAE.Exp e,e1,se,te;
  Integer i,j;
  list<DAE.SymbolicOperation> ops;
algorithm
  (e,(ops,(se,te,i))) := inTpl;
  // BackendDump.debugStrExpStrExpStr(("Repalce ",se," with ",te,"\n"));
  ((e1,j)) := Expression.replaceExp(e,se,te);
  ops := Util.if_(j>0, DAE.SUBSTITUTION({e1},e)::ops, ops);
  // BackendDump.debugStrExpStrExpStr(("Old ",e," new ",e1,"\n"));
  outTpl := ((e1,(ops,(se,te,i+j))));
end replaceExp;

/* 
 * remove unused parameter
 */

public function removeUnusedParameter
"function: removeUnusedParameter
  author: Frenkel TUD 2011-04
  This function remove unused parameters  
  in BackendDAE.BackendDAE to get speed up for compilation of
  target code"
  input BackendDAE.BackendDAE inDlow;
  output BackendDAE.BackendDAE outDlow;
algorithm
  outDlow := match (inDlow)
    local
      BackendDAE.Variables knvars,exobj,knvars1,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcs;
      BackendDAE.EventInfo einfo;
      BackendDAE.SymbolicJacobians symjacs;
      list<BackendDAE.WhenClause> whenClauseLst;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.EqSystems eqs;
      BackendDAE.BackendDAEType btp;      
    case (BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo as BackendDAE.EVENT_INFO(whenClauseLst=whenClauseLst),eoc,btp,symjacs)))
      equation
        knvars1 = BackendVariable.emptyVars();
        ((knvars,knvars1)) = BackendVariable.traverseBackendDAEVars(knvars,copyNonParamVariables,(knvars,knvars1));
        ((_,knvars1)) = List.fold1(eqs,BackendDAEUtil.traverseBackendDAEExpsEqSystem,checkUnusedVariables,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsVars(knvars,checkUnusedParameter,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsVars(aliasVars,checkUnusedParameter,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsEqns(remeqns,checkUnusedParameter,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsEqns(inieqns,checkUnusedParameter,(knvars,knvars1));
        (_,(_,knvars1)) = BackendDAETransform.traverseBackendDAEExpsWhenClauseLst(whenClauseLst,checkUnusedParameter,(knvars,knvars1));
      then 
        BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars1,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeUnusedParameter;

protected function copyNonParamVariables
"author: Frenkel TUD 2011-05"
 input tuple<BackendDAE.Var, tuple<BackendDAE.Variables,BackendDAE.Variables>> inTpl;
 output tuple<BackendDAE.Var, tuple<BackendDAE.Variables,BackendDAE.Variables>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v;
      BackendDAE.Variables vars,vars1;
      DAE.ComponentRef cr;
    case ((v as BackendDAE.VAR(varName = cr,varKind = BackendDAE.PARAM()),(vars,vars1)))
      then
        ((v,(vars,vars1)));
    case ((v as BackendDAE.VAR(varName = cr),(vars,vars1)))
      equation
        vars1 = BackendVariable.addVar(v,vars1);
      then
        ((v,(vars,vars1)));
  end matchcontinue;
end copyNonParamVariables;

protected function checkUnusedParameter
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> inTpl;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> outTpl;
algorithm
  outTpl :=
  matchcontinue inTpl
    local  
      DAE.Exp exp;
      BackendDAE.Variables vars,vars1;
    case ((exp,(vars,vars1)))
      equation
         ((_,(_,vars1))) = Expression.traverseExp(exp,checkUnusedParameterExp,(vars,vars1));
       then
        ((exp,(vars,vars1)));
    case _ then inTpl;
  end matchcontinue;
end checkUnusedParameter;

protected function checkUnusedParameterExp
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> inTuple;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e,e1;
      BackendDAE.Variables vars,vars1;
      DAE.ComponentRef cr;
      list<DAE.Exp> expl;
      list<DAE.Var> varLst;
      BackendDAE.Var var;
    
    // special case for time, it is never part of the equation system  
    case ((e as DAE.CREF(componentRef = DAE.CREF_IDENT(ident="time")),(vars,vars1)))
      then ((e, (vars,vars1)));
    
    // Special Case for Records
    case ((e as DAE.CREF(componentRef = cr,ty= DAE.T_COMPLEX(varLst=varLst,complexClassType=ClassInf.RECORD(_))),(vars,vars1)))
      equation
        expl = List.map1(varLst,Expression.generateCrefsExpFromExpVar,cr);
        ((_,(vars,vars1))) = Expression.traverseExpList(expl,checkUnusedParameterExp,(vars,vars1));
      then
        ((e, (vars,vars1)));

    // Special Case for Arrays
    case ((e as DAE.CREF(ty = DAE.T_ARRAY(ty=_)),(vars,vars1)))
      equation
        ((e1,(_,true))) = BackendDAEUtil.extendArrExp((e,(NONE(),false)));
        ((_,(vars,vars1))) = Expression.traverseExp(e1,checkUnusedParameterExp,(vars,vars1));
      then
        ((e, (vars,vars1)));
    
    // case for functionpointers    
    case ((e as DAE.CREF(ty=DAE.T_FUNCTION_REFERENCE_FUNC(builtin=_)),(vars,vars1)))
      then
        ((e, (vars,vars1)));

    // already there
    case ((e as DAE.CREF(componentRef = cr),(vars,vars1)))
      equation
         (_,_) = BackendVariable.getVar(cr, vars1);
      then
        ((e, (vars,vars1)));

    // add it
    case ((e as DAE.CREF(componentRef = cr),(vars,vars1)))
      equation
         (var::_,_) = BackendVariable.getVar(cr, vars);
         vars1 = BackendVariable.addVar(var,vars1);
      then
        ((e, (vars,vars1)));
    
    case _ then inTuple;
  end matchcontinue;
end checkUnusedParameterExp;

/* 
 * remove unused variables
 */

public function removeUnusedVariables
"function: removeUnusedVariables
  author: Frenkel TUD 2011-04
  This function remove unused variables  
  from BackendDAE.BackendDAE to get speed up for compilation of
  target code"
  input BackendDAE.BackendDAE inDlow;
  output BackendDAE.BackendDAE outDlow;
algorithm
  outDlow := match (inDlow)
    local
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,knvars1,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      BackendDAE.EventInfo einfo;
      list<BackendDAE.WhenClause> whenClauseLst;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EqSystems eqs;    
      BackendDAE.BackendDAEType btp;
      
    case (BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo as BackendDAE.EVENT_INFO(whenClauseLst=whenClauseLst),eoc,btp,symjacs)))
      equation
        knvars1 = BackendVariable.emptyVars();
        ((_,knvars1)) = List.fold1(eqs,BackendDAEUtil.traverseBackendDAEExpsEqSystem,checkUnusedVariables,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsVars(knvars,checkUnusedVariables,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsVars(aliasVars,checkUnusedVariables,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsEqns(remeqns,checkUnusedVariables,(knvars,knvars1));
        ((_,knvars1)) = BackendDAEUtil.traverseBackendDAEExpsEqns(inieqns,checkUnusedVariables,(knvars,knvars1));
        (_,(_,knvars1)) = BackendDAETransform.traverseBackendDAEExpsWhenClauseLst(whenClauseLst,checkUnusedVariables,(knvars,knvars1));
      then 
        BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars1,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeUnusedVariables;

protected function checkUnusedVariables
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> inTpl;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> outTpl;
algorithm
  outTpl :=
  matchcontinue inTpl
    local  
      DAE.Exp exp;
      BackendDAE.Variables vars,vars1;
    case ((exp,(vars,vars1)))
      equation
         ((_,(_,vars1))) = Expression.traverseExp(exp,checkUnusedVariablesExp,(vars,vars1));
       then
        ((exp,(vars,vars1)));
    case _ then inTpl;
  end matchcontinue;
end checkUnusedVariables;

protected function checkUnusedVariablesExp
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> inTuple;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,BackendDAE.Variables>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e,e1;
      BackendDAE.Variables vars,vars1;
      DAE.ComponentRef cr;
      list<DAE.Exp> expl;
      list<DAE.Var> varLst;
      BackendDAE.Var var;
    
    // special case for time, it is never part of the equation system  
    case ((e as DAE.CREF(componentRef = DAE.CREF_IDENT(ident="time")),(vars,vars1)))
      then ((e, (vars,vars1)));
    
    // Special Case for Records
    case ((e as DAE.CREF(componentRef = cr,ty= DAE.T_COMPLEX(varLst=varLst,complexClassType=ClassInf.RECORD(_))),(vars,vars1)))
      equation
        expl = List.map1(varLst,Expression.generateCrefsExpFromExpVar,cr);
        ((_,(vars,vars1))) = Expression.traverseExpList(expl,checkUnusedVariablesExp,(vars,vars1));
      then
        ((e, (vars,vars1)));

    // Special Case for Arrays
    case ((e as DAE.CREF(ty = DAE.T_ARRAY(ty=_)),(vars,vars1)))
      equation
        ((e1,(_,true))) = BackendDAEUtil.extendArrExp((e,(NONE(),false)));
        ((_,(vars,vars1))) = Expression.traverseExp(e1,checkUnusedVariablesExp,(vars,vars1));
      then
        ((e, (vars,vars1)));
    
    // case for functionpointers    
    case ((e as DAE.CREF(ty=DAE.T_FUNCTION_REFERENCE_FUNC(builtin=_)),(vars,vars1)))
      then
        ((e, (vars,vars1)));

    // already there
    case ((e as DAE.CREF(componentRef = cr),(vars,vars1)))
      equation
         (_,_) = BackendVariable.getVar(cr, vars1);
      then
        ((e, (vars,vars1)));

    // add it
    case ((e as DAE.CREF(componentRef = cr),(vars,vars1)))
      equation
         (var::_,_) = BackendVariable.getVar(cr, vars);
         vars1 = BackendVariable.addVar(var,vars1);
      then
        ((e, (vars,vars1)));
    
    case _ then inTuple;
  end matchcontinue;
end checkUnusedVariablesExp;

/* 
 * remove unused functions
 */

public function removeUnusedFunctions
"function: removeUnusedFunctions
  author: Frenkel TUD 2012-03
  This function remove unused functions  
  from DAE.FunctionTree to get speed up for compilation of
  target code"
  input BackendDAE.BackendDAE inDlow;
  output BackendDAE.BackendDAE outDlow;   
algorithm
  outDlow := match (inDlow)
    local
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcs,usedfuncs;
      BackendDAE.Variables knvars,exobj,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      BackendDAE.EventInfo einfo;
      list<BackendDAE.WhenClause> whenClauseLst;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EqSystems eqs;    
      BackendDAE.BackendDAEType btp;
      
    case (BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo as BackendDAE.EVENT_INFO(whenClauseLst=whenClauseLst),eoc,btp,symjacs)))
      equation
        usedfuncs = copyRecordConstructorAndExternalObjConstructorDestructor(funcs);
        ((_,usedfuncs)) = List.fold1(eqs,BackendDAEUtil.traverseBackendDAEExpsEqSystem,checkUnusedFunctions,(funcs,usedfuncs));
        ((_,usedfuncs)) = BackendDAEUtil.traverseBackendDAEExpsVars(knvars,checkUnusedFunctions,(funcs,usedfuncs));
        ((_,usedfuncs)) = BackendDAEUtil.traverseBackendDAEExpsVars(exobj,checkUnusedFunctions,(funcs,usedfuncs));        
        ((_,usedfuncs)) = BackendDAEUtil.traverseBackendDAEExpsVars(aliasVars,checkUnusedFunctions,(funcs,usedfuncs));
        ((_,usedfuncs)) = BackendDAEUtil.traverseBackendDAEExpsEqns(remeqns,checkUnusedFunctions,(funcs,usedfuncs));
        ((_,usedfuncs)) = BackendDAEUtil.traverseBackendDAEExpsEqns(inieqns,checkUnusedFunctions,(funcs,usedfuncs));
        (_,(_,usedfuncs)) = BackendDAETransform.traverseBackendDAEExpsWhenClauseLst(whenClauseLst,checkUnusedFunctions,(funcs,usedfuncs));
        //traverse Symbolic jacobians
        ((funcs,usedfuncs)) = removeUnusedFunctionsSymJacs(symjacs,(funcs,usedfuncs));
      then 
        BackendDAE.DAE(eqs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,usedfuncs,einfo,eoc,btp,symjacs));
  end match;
end removeUnusedFunctions;

protected function copyRecordConstructorAndExternalObjConstructorDestructor
  input DAE.FunctionTree inFunctions;
  output DAE.FunctionTree outFunctions;
protected
  list<DAE.Function> funcelems;
algorithm
  funcelems := DAEUtil.getFunctionList(inFunctions);
  outFunctions := List.fold(funcelems,copyRecordConstructorAndExternalObjConstructorDestructorFold,DAEUtil.emptyFuncTree);
end copyRecordConstructorAndExternalObjConstructorDestructor;

protected function copyRecordConstructorAndExternalObjConstructorDestructorFold
  input DAE.Function inFunction;
  input DAE.FunctionTree inFunctions;
  output DAE.FunctionTree outFunctions;
algorithm
  outFunctions :=     
  matchcontinue (inFunction,inFunctions)
    local  
      DAE.Function f;
      DAE.FunctionTree funcs,funcs1;
      Absyn.Path path;
    // copy record constructors
    case (f as DAE.RECORD_CONSTRUCTOR(path=path),funcs)
      equation
         funcs1 = DAEUtil.avlTreeAdd(funcs, path, SOME(f));
       then
        funcs1;
    // copy external objects constructors/destructors
    case (f as DAE.FUNCTION(path = path),funcs)
      equation
         true = boolOr(
                  stringEq(Absyn.pathLastIdent(path), "constructor"), 
                  stringEq(Absyn.pathLastIdent(path), "destructor"));
         funcs1 = DAEUtil.avlTreeAdd(funcs, path, SOME(f));
       then
        funcs1;
    case (f,funcs) then funcs;
  end matchcontinue;
end copyRecordConstructorAndExternalObjConstructorDestructorFold;

protected function removeUnusedFunctionsSymJacs
  input BackendDAE.SymbolicJacobians inSymJacs;
  input tuple<DAE.FunctionTree,DAE.FunctionTree> inFuncsTpl;
  output tuple<DAE.FunctionTree,DAE.FunctionTree> outFuncsTpl;
algorithm
  outFuncsTpl := match(inSymJacs,inFuncsTpl)
  local
    BackendDAE.BackendDAE bdae;
    BackendDAE.SymbolicJacobians rest;
    DAE.FunctionTree funcs, usedfuncs, usedfuncs2;
    list<tuple<DAE.AvlKey, DAE.AvlValue>> treelst;
    case ({},(funcs,usedfuncs)) then ((funcs,usedfuncs));
    case ((NONE(),_,_)::rest,(funcs,usedfuncs))
      then removeUnusedFunctionsSymJacs(rest,(funcs,usedfuncs));      
    case ((SOME((bdae,_,_,_,_)),_,_)::rest,(funcs,usedfuncs))
      equation
         bdae = BackendDAEUtil.addBackendDAEFunctionTree(funcs,bdae);
         BackendDAE.DAE(shared=BackendDAE.SHARED(functionTree=usedfuncs2)) = removeUnusedFunctions(bdae);
         treelst = DAEUtil.avlTreeToList(usedfuncs2);
         usedfuncs = DAEUtil.avlTreeAddLst(treelst, usedfuncs);
      then removeUnusedFunctionsSymJacs(rest,(funcs,usedfuncs));
      //else then inFuncsTpl;
  end match;
end removeUnusedFunctionsSymJacs;

protected function checkUnusedFunctions
  input tuple<DAE.Exp, tuple<DAE.FunctionTree,DAE.FunctionTree>> inTpl;
  output tuple<DAE.Exp, tuple<DAE.FunctionTree,DAE.FunctionTree>> outTpl;
algorithm
  outTpl :=
  matchcontinue inTpl
    local  
      DAE.Exp exp;
      DAE.FunctionTree func,usefuncs,usefuncs1;
    case ((exp,(func,usefuncs)))
      equation
         ((_,(_,usefuncs1))) = Expression.traverseExp(exp,checkUnusedFunctionsExp,(func,usefuncs));
       then
        ((exp,(func,usefuncs1)));
    case _ then inTpl;
  end matchcontinue;
end checkUnusedFunctions;

protected function checkUnusedFunctionsExp
  input tuple<DAE.Exp, tuple<DAE.FunctionTree,DAE.FunctionTree>> inTuple;
  output tuple<DAE.Exp, tuple<DAE.FunctionTree,DAE.FunctionTree>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e;
      DAE.FunctionTree func,usefuncs,usefuncs1,usefuncs2;
      Absyn.Path path;
      Option<DAE.Function> f;    
      list<DAE.Element> body;  
    
    // already there
    case ((e as DAE.CALL(path = path),(func,usefuncs)))
      equation
         _ = DAEUtil.avlTreeGet(usefuncs, path);
      then
        ((e, (func,usefuncs)));

    // add it
    case ((e as DAE.CALL(path = path),(func,usefuncs)))
      equation
         (f,body) = getFunctionAndBody(path,func);
         usefuncs1 = DAEUtil.avlTreeAdd(usefuncs, path, f);
         // print("add function " +& Absyn.pathStringNoQual(path) +& "\n");
         (_,(_,usefuncs2)) = DAEUtil.traverseDAE2(body,checkUnusedFunctions,(func,usefuncs1));
      then
        ((e, (func,usefuncs2)));
        
    // already there
    case ((e as DAE.PARTEVALFUNCTION(path = path),(func,usefuncs)))
      equation
         _ = DAEUtil.avlTreeGet(usefuncs, path);
      then
        ((e, (func,usefuncs)));
        
    // add it
    case ((e as DAE.PARTEVALFUNCTION(path = path),(func,usefuncs)))
      equation
         (f as SOME(_)) = DAEUtil.avlTreeGet(func, path);
         usefuncs1 = DAEUtil.avlTreeAdd(usefuncs, path, f);
         // print("add partial function " +& Absyn.pathStringNoQual(path) +& "\n");
      then
        ((e, (func,usefuncs1)));
            
    case _ then inTuple;
  end matchcontinue;
end checkUnusedFunctionsExp;

protected function getFunctionAndBody
"function: getFunctionBody
  returns the body of a function"
  input Absyn.Path inPath;
  input DAE.FunctionTree fns;
  output Option<DAE.Function> outFn;
  output list<DAE.Element> outFnBody;
algorithm
  (outFn,outFnBody) := matchcontinue(inPath,fns)
    local
      Absyn.Path p;
      Option<DAE.Function> fn;
      list<DAE.Element> body;
      DAE.FunctionTree ftree;
      String msg;
    // handle normal functions
    case(p,ftree)
      equation
        (fn as SOME(DAE.FUNCTION(functions = DAE.FUNCTION_DEF(body = body)::_))) = DAEUtil.avlTreeGet(ftree,p);
      then (fn,body);
    // adrpo: also the external functions!
    case(p,ftree)
      equation
        (fn as SOME(DAE.FUNCTION(functions = DAE.FUNCTION_EXT(body = body)::_))) = DAEUtil.avlTreeGet(ftree,p);
      then (fn,body);
    
    case(p,_)
      equation
        msg = "BackendDAEOptimize.getFunctionBody failed for function " +& Absyn.pathStringNoQual(p);
        // print(msg +& "\n");
        Debug.fprintln(Flags.FAILTRACE, msg);
        // Error.addMessage(Error.INTERNAL_ERROR, {msg});
      then
        fail();
  end matchcontinue;
end getFunctionAndBody;

/* 
 * constant jacobians. Linear system of equations (A x = b) where
 * A and b are constants.
 */

public function constantLinearSystem
"function constantLinearSystem"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,constantLinearSystem0,false);
end constantLinearSystem;

protected function constantLinearSystem0
"function constantLinearSystem"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) := 
    match(isyst,sharedChanged)
    local
      BackendDAE.StrongComponents comps;
      Boolean b,b1,b2;
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;
    case (syst as BackendDAE.EQSYSTEM(matching=BackendDAE.MATCHING(comps=comps)),(shared, b1))
      equation
        (syst,shared,b2) = constantLinearSystem1(syst,shared,comps);
        syst = constantLinearSystem2(b2,syst);
        b = b1 or b2;
      then
        (syst,(shared,b));
  end match;  
end constantLinearSystem0;

protected function constantLinearSystem2
"function constantLinearSystem"
  input Boolean b;
  input BackendDAE.EqSystem isyst;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match(b,isyst)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns;
      BackendDAE.StrongComponents comps;
      array<Integer> ass1,ass2;
      BackendDAE.StateSets stateSets;
    case (false,_) then isyst;
//    case (true,BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,matching=BackendDAE.NO_MATCHING()))
    case (true,BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets))
      equation
        // remove empty entries from vars/eqns
        vars = BackendVariable.listVar1(BackendVariable.varList(vars));
        eqns = BackendEquation.listEquation(BackendEquation.equationList(eqns));
      then
        BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);     
/*    case (true,BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,matching=BackendDAE.MATCHING(ass1=ass1,ass2=ass2,comps=comps)))
      then
        updateEquationSystemMatching(vars,eqns,ass1,ass2,comps);
*/  end match;  
end constantLinearSystem2;

protected function constantLinearSystem1
"function constantLinearSystem1"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input BackendDAE.StrongComponents inComps;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
  output Boolean outRunMatching;
algorithm
  (osyst,oshared,outRunMatching):=
  matchcontinue (isyst,ishared,inComps)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns;
      BackendDAE.StrongComponents comps;
      BackendDAE.StrongComponent comp,comp1;
      Boolean b,b1;
      list<BackendDAE.Equation> eqn_lst;
      list<BackendDAE.Var> var_lst;
      list<Integer> eindex,vindx;
      list<tuple<Integer, Integer, BackendDAE.Equation>> jac;
      BackendDAE.EqSystem syst;
      BackendDAE.Shared shared;
      
    case (syst,shared,{})
      then (syst,shared,false);
    case (syst as BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns),shared,(comp as BackendDAE.EQUATIONSYSTEM(eqns=eindex,vars=vindx,jac=SOME(jac),jacType=BackendDAE.JAC_CONSTANT()))::comps)
      equation
        eqn_lst = BackendEquation.getEqns(eindex,eqns);        
        var_lst = List.map1r(vindx, BackendVariable.getVarAt, vars);
        (syst,shared) = solveLinearSystem(syst,shared,eqn_lst,eindex,var_lst,vindx,jac);
        (syst,shared,b) = constantLinearSystem1(syst,shared,comps);
      then
        (syst,shared,true);
    case (syst,shared,(comp as BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=comp1))::comps)
      equation
        (syst,shared,b) = constantLinearSystem1(syst,shared,{comp1});
        (syst,shared,b1) = constantLinearSystem1(syst,shared,comps);
      then
        (syst,shared,b1 or b);
    case (syst,shared,comp::comps)
      equation
        (syst,shared,b) = constantLinearSystem1(syst,shared,comps);
      then
        (syst,shared,b);
  end matchcontinue;  
end constantLinearSystem1;

protected function solveLinearSystem
"function constantLinearSystem1"
  input BackendDAE.EqSystem syst;
  input BackendDAE.Shared ishared;
  input list<BackendDAE.Equation> eqn_lst; 
  input list<Integer> eqn_indxs;
  input list<BackendDAE.Var> var_lst;
  input list<Integer> var_indxs;
  input list<tuple<Integer, Integer, BackendDAE.Equation>> jac;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
algorithm
  (osyst,oshared):=
  match (syst,ishared,eqn_lst,eqn_indxs,var_lst,var_indxs,jac)
    local
      BackendDAE.Variables vars,vars1,v;
      BackendDAE.EquationArray eqns,eqns1;
      list<DAE.Exp> beqs;
      list<DAE.ElementSource> sources;
      list<Real> rhsVals,solvedVals;
      list<list<Real>> jacVals;
      Integer linInfo;
      list<DAE.ComponentRef> names;
      BackendDAE.Matching matching;
      DAE.FunctionTree funcs;
      BackendDAE.Shared shared;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,matching=matching,stateSets=stateSets),BackendDAE.SHARED(functionTree=funcs),_,_,_,_,_)
      equation
        eqns1 = BackendEquation.listEquation(eqn_lst);
        v = BackendVariable.listVar1(var_lst);
        ((_,beqs,sources,_)) = BackendEquation.traverseBackendDAEEqns(eqns1,BackendEquation.equationToExp,(v,{},{},SOME(funcs)));
        beqs = listReverse(beqs);
        rhsVals = ValuesUtil.valueReals(List.map(beqs,Ceval.cevalSimple));
        jacVals = evaluateConstantJacobian(listLength(var_lst),jac);
        (solvedVals,linInfo) = System.dgesv(jacVals,rhsVals);
        names = List.map(var_lst,BackendVariable.varCref);  
        checkLinearSystem(linInfo,names,jacVals,rhsVals,eqn_lst);
        sources = List.map1(sources, DAEUtil.addSymbolicTransformation, DAE.LINEAR_SOLVED(names,jacVals,rhsVals,solvedVals));           
        (vars1,shared) = changeconstantLinearSystemVars(var_lst,solvedVals,sources,var_indxs,vars,ishared);
        eqns = List.fold(eqn_indxs,BackendEquation.equationRemove,eqns);
      then
        (BackendDAE.EQSYSTEM(vars1,eqns,NONE(),NONE(),matching,stateSets),shared);
  end match;  
end solveLinearSystem;

protected function changeconstantLinearSystemVars 
  input list<BackendDAE.Var> inVarLst;
  input list<Real> inSolvedVals;
  input list<DAE.ElementSource> inSources;
  input list<Integer> var_indxs;
  input BackendDAE.Variables inVars;
  input BackendDAE.Shared ishared;
  output BackendDAE.Variables outVars;
  output BackendDAE.Shared oshared;
algorithm
    (outVars,oshared) := match (inVarLst,inSolvedVals,inSources,var_indxs,inVars,ishared)
    local
      BackendDAE.Var v,v1;
      list<BackendDAE.Var> varlst;
      DAE.ElementSource s;
      list<DAE.ElementSource> slst;
      BackendDAE.Variables vars,vars1,vars2;
      Real r;
      list<Real> rlst;
      BackendDAE.Shared shared;
      Integer indx;
      list<Integer> vindxs;
    case ({},{},{},_,vars,_) then (vars,ishared);      
    case (v::varlst,r::rlst,s::slst,indx::vindxs,vars,_)
      equation
        v1 = BackendVariable.setBindExp(v,DAE.RCONST(r));
        v1 = BackendVariable.setVarStartValue(v1,DAE.RCONST(r));
        // ToDo: merge source of var and equation
        (vars1,_) = BackendVariable.removeVar(indx, vars);
        shared = BackendVariable.addKnVarDAE(v1,ishared);
        (vars2,shared) = changeconstantLinearSystemVars(varlst,rlst,slst,vindxs,vars1,shared);
      then (vars2,shared);
  end match; 
end changeconstantLinearSystemVars;

public function evaluateConstantJacobian
  "Evaluate a constant jacobian so we can solve a linear system during runtime"
  input Integer size;
  input list<tuple<Integer,Integer,BackendDAE.Equation>> jac;
  output list<list<Real>> vals;
protected
  array<array<Real>> valarr;
  array<Real> tmp;
  list<array<Real>> tmp2;
  list<Real> rs;
algorithm
  rs := List.fill(0.0,size);
  tmp := listArray(rs);
  tmp2 := List.map(List.fill(tmp,size),arrayCopy);
  valarr := listArray(tmp2);
  List.map1_0(jac,evaluateConstantJacobian2,valarr);
  tmp2 := arrayList(valarr);
  vals := List.map(tmp2,arrayList);
end evaluateConstantJacobian;

protected function evaluateConstantJacobian2
  input tuple<Integer,Integer,BackendDAE.Equation> jac;
  input array<array<Real>> vals;
algorithm
  _ := match (jac,vals)
    local
      DAE.Exp exp;
      Integer i1,i2;
      Real r;
    case ((i1,i2,BackendDAE.RESIDUAL_EQUATION(exp=exp)),_)
      equation
        Values.REAL(r) = Ceval.cevalSimple(exp);
        _ = arrayUpdate(arrayGet(vals,i1),i2,r);
      then ();
  end match;
end evaluateConstantJacobian2;

protected function checkLinearSystem
  input Integer info;
  input list<DAE.ComponentRef> vars;
  input list<list<Real>> jac;
  input list<Real> rhs;
  input list<BackendDAE.Equation> eqnlst;
algorithm
  _ := matchcontinue (info,vars,jac,rhs,eqnlst)
    local
      String infoStr,syst,varnames,varname,rhsStr,jacStr,eqnstr;
    case (0,_,_,_,_) then ();
    case (_,_,_,_,_)
      equation
        true = info > 0;
        varname = ComponentReference.printComponentRefStr(listGet(vars,info));
        infoStr = intString(info);
        varnames = stringDelimitList(List.map(vars,ComponentReference.printComponentRefStr)," ;\n  ");
        rhsStr = stringDelimitList(List.map(rhs, realString)," ;\n  ");
        jacStr = stringDelimitList(List.map1(List.mapList(jac,realString),stringDelimitList," , ")," ;\n  ");
        eqnstr = BackendDump.dumpEqnsStr(eqnlst);
        syst = stringAppendList({"\n",eqnstr,"\n[\n  ", jacStr, "\n]\n  *\n[\n  ",varnames,"\n]\n  =\n[\n  ",rhsStr,"\n]"});
        Error.addMessage(Error.LINEAR_SYSTEM_SINGULAR, {syst,infoStr,varname});
      then fail();
    case (_,_,_,_,_)
      equation
        true = info < 0;
        varnames = stringDelimitList(List.map(vars,ComponentReference.printComponentRefStr)," ;\n  ");
        rhsStr = stringDelimitList(List.map(rhs, realString)," ; ");
        jacStr = stringDelimitList(List.map1(List.mapList(jac,realString),stringDelimitList," , ")," ; ");
        eqnstr = BackendDump.dumpEqnsStr(eqnlst);
        syst = stringAppendList({eqnstr,"\n[", jacStr, "] * [",varnames,"] = [",rhsStr,"]"});
        Error.addMessage(Error.LINEAR_SYSTEM_INVALID, {"LAPACK/dgesv",syst});
      then fail();
  end matchcontinue;
end checkLinearSystem;




/*  
 * tearing system of equations stuff
 *
 */ 
public function tearingSystem
" function: tearingSystem
  author: Frenkel TUD
  Pervormes tearing method on a system.
  This is just a funktion to check the flack tearing.
  All other will be done at tearingSystem1."
  input BackendDAE.BackendDAE inDlow;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input BackendDAE.StrongComponents inComps;
  output BackendDAE.BackendDAE outDlow;
  output array<Integer> outV1;
  output array<Integer> outV2;
  output list<list<Integer>> outComps;
  output list<list<Integer>> outResEqn;
  output list<list<Integer>> outTearVar;
algorithm
  (outDlow,outV1,outV2,outComps,outResEqn,outTearVar):=
  matchcontinue (inDlow,inV1,inV2,inComps)
    local
      BackendDAE.BackendDAE dlow,dlow_1,dlow1;
      BackendDAE.IncidenceMatrix m,m_1;
      BackendDAE.IncidenceMatrixT mT,mT_1;
      array<Integer> v1,v2,v1_1,v2_1;
      BackendDAE.StrongComponents comps;
      list<list<Integer>> r,t,comps_1,comps_2;
    case (dlow as BackendDAE.DAE(eqs=BackendDAE.EQSYSTEM(m=SOME(m),mT=SOME(mT))::{}),v1,v2,comps)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print, "Tearing\n==========\n");
        // get residual eqn and tearing var for each block
        // copy dlow
        dlow1 = BackendDAEUtil.copyBackendDAE(dlow);
        comps_1 = List.map(comps,getEqnIndxFromComp);
        (r,t,_,dlow_1,m_1,mT_1,v1_1,v2_1,comps_2) = tearingSystem1(dlow,dlow1,m,mT,v1,v2,comps_1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpIncidenceMatrix, m_1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpIncidenceMatrixT, mT_1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printBackendDAE, dlow_1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpMatching, v1_1);
        //Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpComponents, comps_2);
        Debug.fcall(Flags.TEARING_DUMP, print, "==========\n");
        Debug.fcall2(Flags.TEARING_DUMP, BackendDump.dumpTearing, r,t);
        Debug.fcall(Flags.TEARING_DUMP, print, "==========\n");
      then
        (dlow_1,v1_1,v2_1,comps_2,r,t);
    case (dlow,v1,v2,comps)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print, "No Tearing\n==========\n");
      then
        fail();
  end matchcontinue;
end tearingSystem;

protected function getEqnIndxFromComp
"function: getEqnIndxFromComp
  author: Frenkel TUD"
  input BackendDAE.StrongComponent inComp;
  output list<Integer> outEqnIndexLst;
algorithm
  outEqnIndexLst:=
  match (inComp)
    local
      Integer e;
      list<Integer> elst;
    case (BackendDAE.SINGLEEQUATION(eqn=e))
      then
        {e};
    case (BackendDAE.EQUATIONSYSTEM(eqns=elst))
      then
        elst;
    case (BackendDAE.SINGLEARRAY(eqn=e))
      then
        {e};
    case (BackendDAE.SINGLEIFEQUATION(eqn=e))
      then
        {e};
    case (BackendDAE.SINGLEALGORITHM(eqn=e))
      then
        {e};
    case (BackendDAE.SINGLECOMPLEXEQUATION(eqn=e))
      then
        {e};
    case (BackendDAE.SINGLEWHENEQUATION(eqn=e))
      then
        {e};
  end match;
end getEqnIndxFromComp;

protected function tearingSystem1
" function: tearingSystem1
  author: Frenkel TUD
  Main loop. Check all Comps and start tearing if
  strong connected components there"
  input BackendDAE.BackendDAE inDlow;
  input BackendDAE.BackendDAE inDlow1;
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<list<Integer>> inComps;
  output list<list<Integer>> outResEqn;
  output list<list<Integer>> outTearVar;
  output BackendDAE.BackendDAE outDlow;
  output BackendDAE.BackendDAE outDlow1;
  output BackendDAE.IncidenceMatrix outM;
  output BackendDAE.IncidenceMatrixT outMT;
  output array<Integer> outV1;
  output array<Integer> outV2;
  output list<list<Integer>> outComps;
algorithm
  (outResEqn,outTearVar,outDlow,outDlow1,outM,outMT,outV1,outV2,outComps):=
  matchcontinue (inDlow,inDlow1,inM,inMT,inV1,inV2,inComps)
    local
      BackendDAE.BackendDAE dlow,dlow_1,dlow_2,dlow1,dlow1_1,dlow1_2,dlow1_3,sub_dae,subSyst,linearDAE,linearDAE1;
      BackendDAE.IncidenceMatrix m,m_1,m_3,m_4,m_subSyst1,m_subSyst2;
      BackendDAE.IncidenceMatrixT mT,mT_1,mT_3,mT_4,mT_subSyst1,mT_subSyst2;
      array<Integer> v1,v2,v1_1,v2_1,v1_2,v2_2,v1_3,v2_3,match1;
      list<list<Integer>> comps,comps_1;
      list<Integer> tvars,comp,comp_1,tearingvars,residualeqns,tearingeqns,residual;
      list<list<Integer>> r,t;
      Integer ll,arrSize,l,sizeArr,NOE;
      list<DAE.ComponentRef> crlst;
      BackendDAE.EqSystem syst,sub_eqSyst,sub_eqSyst2,eqSystem,relaxedEqSystem;
      BackendDAE.Shared shared,sub_shared,sub_shared2,relaxedShared;
      array<DAE.Exp> expArr,eArr,resEq;
      list<Option<BackendDAE.Equation>> eq_subSyst_Lst;
      array<Option<BackendDAE.Equation>> eq_subSyst_Arr,transEqArr;
      BackendDAE.EquationArray eqns_subSyst,eqArray,removedEqs,emptyEqns;
      Option<list<tuple<Integer, Integer, BackendDAE.Equation>>> jac_subSyst,jacNewton;
      list<tuple<Integer, Integer, BackendDAE.Equation>> jac_subSyst1;
      tuple<Integer, Integer, BackendDAE.Equation> row;
      BackendDAE.Variables vars_subSyst,vars,variables,varsempty,externalObjects,emptyVars,knownVars,vars1,tVariables;
      BackendDAE.Equation eq;
      DAE.Exp e,expArr1,resEq1;
      array<BackendDAE.Equation> eqArr,inEqArr;
      list<BackendDAE.Equation> eqLst;
      list<DAE.ComponentRef> lstRef,crefLst;
      array<DAE.ComponentRef> arrRef;
      array<list<BackendDAE.CrefIndex>> arr,emptyArrCI;
      array<Option<BackendDAE.Var>> emptyarr,optVarArrEmpty;
      BackendDAE.Matching matching;
      BackendDAE.VariableArray varArrEmpty;
      BackendDAE.Variables aliasVars;
      array<DAE.Constraint> constraints;
      DAE.FunctionTree functionTree;
      Env.Cache cache;
      Env.Env env;
      BackendDAE.EventInfo eventInfo;
      BackendDAE.ExternalObjectClasses extObjClasses;
      BackendDAE.BackendDAEType backenDAEType;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EquationArray eqns;
      list<BackendDAE.Equation> eqn_lst;
      list<BackendDAE.Var> var_lst;
      BackendDAE.IncidenceMatrix m_new;
      BackendDAE.IncidenceMatrixT mT_new;
      array<Integer> v1_new,v2_new;
      list<Integer> eqnsNewton,varsNewton;
      BackendDAE.StrongComponent comps_Newton;
      BackendDAE.JacobianType jacTypeNewton;
      array< .DAE.ClassAttributes> classAttrs;
    case (dlow,dlow1,m,mT,v1,v2,{})
      equation
        print("no comps\n");
      then
        ({},{},dlow,dlow1,m,mT,v1,v2,{});
    case (dlow,dlow1,m,mT,v1,v2,comp::comps)
      equation
        true = Flags.isSet(Flags.TEARING_AND_RELAXATION);
        // block ?
        ll = listLength(comp);
        true = ll > 1;
        // get all interesting vars
        (tvars,crlst) = getTearingVars(m,v1,v2,comp,dlow);
        // try tearing
        (residualeqns,tearingvars,tearingeqns,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem2(dlow,dlow1,m,mT,v1,v2,comp,tvars,{},{},{},{},crlst);
        //BackendDump.dumpTearing({residualeqns},{tearingvars});
        //-------------
        l = listLength(tearingvars);
        sub_dae = BackendDAEUtil.copyBackendDAE(dlow1_1);
        BackendDAE.DAE({sub_eqSyst},sub_shared) = dlow1_1;
        (m_subSyst1,mT_subSyst1) = BackendDAEUtil.incidenceMatrix(sub_eqSyst, BackendDAE.NORMAL());
        residual = residualeqns;
        tvars = tearingvars;
        BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns) = sub_eqSyst;
        vars1 = vars;
        eqn_lst = BackendEquation.getEqns(residualeqns,eqns);
        eq = listGet(eqn_lst,1);
        var_lst = List.map1r(tvars, BackendVariable.getVarAt, vars);
        subSyst = getSubSystemDaeForVars(residual,tvars,dlow1_1);
        BackendDAE.DAE({sub_eqSyst2},sub_shared2) = subSyst;
        (m_subSyst2,mT_subSyst2) = BackendDAEUtil.incidenceMatrix(sub_eqSyst2, BackendDAE.NORMAL());
        BackendDAE.EQSYSTEM(orderedVars=vars_subSyst,orderedEqs=eqns_subSyst) = sub_eqSyst2;
        BackendDAE.EQUATION_ARRAY(sizeArr,NOE,arrSize,eq_subSyst_Arr) = eqns_subSyst;
        eq_subSyst_Lst = arrayList(eq_subSyst_Arr);
        transEqArr = equationToResidualFormArr(eq_subSyst_Arr,1,l);
        BackendDAE.SHARED(knownVars,externalObjects,aliasVars,_,removedEqs,constraints,classAttrs,cache,env,functionTree,eventInfo,extObjClasses,backenDAEType,symjacs) = sub_shared2;
        eqns_subSyst = BackendDAE.EQUATION_ARRAY(sizeArr,NOE,arrSize,transEqArr);
        jac_subSyst = BackendDAEUtil.calculateJacobian(vars_subSyst, eqns_subSyst, m_subSyst2, false,sub_shared);
        SOME(jac_subSyst1) = jac_subSyst;
        row = listGet(jac_subSyst1,1);
        (_,_,eq) = row;
        BackendDAE.RESIDUAL_EQUATION(exp=e) = eq;
        l = listLength(tvars);
        eArr = arrayCreate(l,DAE.RCONST(0.0));
        varsempty = BackendVariable.emptyVars();
        BackendDAE.VARIABLES(_,varArrEmpty,_,_) = varsempty;
        BackendDAE.VARIABLE_ARRAY(_,_,optVarArrEmpty) = varArrEmpty;
        vars = vars_subSyst;
        crefLst = createCrefLstForNewton(l,1,{});
        variables = newVariablesForNewton(l,crefLst,varsempty);
        (expArr,lstRef) = matrixVectorMultiplication(jac_subSyst1,1,1,variables,l,eArr,{});  //any entry for inExpArr
        expArr1 = arrayGet(expArr,1);
        resEq = equationToExpArr(eq_subSyst_Arr,1,arrayCreate(l,expArr1));
        resEq1 = arrayGet(resEq,1);
        expArr = buildLinSystForNewton(expArr,resEq,1,expArr);  //last entry does not matter  how to choose, just to have an array<DAE.Exp>
        expArr1 = arrayGet(expArr,1);
        inEqArr = arrayCreate(l,eq);
        eqArr = expToEquationArr(expArr,1,inEqArr);
        eqLst = arrayList(eqArr);
        eqArray = BackendEquation.listEquation(eqLst);  //BackendDAE.EquationArray
        emptyArrCI = arrayCreate(l,{});
        arrRef = listArray(lstRef);
        arr = arrLstCrefIndex(arrRef,1,emptyArrCI);
        arrSize = arrayLength(arr);
        emptyarr = arrayCreate(arrSize, NONE());
        BackendDAE.SHARED(knownVars,externalObjects,aliasVars,_,removedEqs,constraints,classAttrs,cache,env,functionTree,eventInfo,extObjClasses,backenDAEType,symjacs) = sub_shared;
        knownVars = BackendVariable.mergeVariables(knownVars,vars1);  //?????
        tVariables = BackendVariable.listVar(var_lst);
        knownVars = BackendVariable.mergeVariables(knownVars,tVariables);
        emptyEqns = BackendEquation.emptyEqns();
        emptyVars = BackendVariable.emptyVars();
        eqSystem = BackendDAE.EQSYSTEM(variables,eqArray,NONE(),NONE(),BackendDAE.NO_MATCHING(),{});
        shared = BackendDAE.SHARED(knownVars,externalObjects,aliasVars,emptyEqns,removedEqs,constraints,classAttrs,cache,env,functionTree,BackendDAE.EVENT_INFO({},{},{},{},0,0),{},BackendDAE.SIMULATION(),{});
        (m_new,mT_new) = BackendDAEUtil.incidenceMatrix(eqSystem,BackendDAE.NORMAL());
        match1 = arrayCreate(l,1);
        matching = BackendDAE.MATCHING(match1,match1,{});
        eqSystem = BackendDAE.EQSYSTEM(variables,eqArray,SOME(m_new),SOME(mT_new),matching,{});
        linearDAE = BackendDAE.DAE({eqSystem},shared);
        eqnsNewton = List.intRange(l);
        varsNewton = List.intRange(l);
        jacNewton = BackendDAEUtil.calculateJacobian(variables,eqArray,m_new,false,sub_shared);
        jacTypeNewton = BackendDAEUtil.analyzeJacobian(variables,eqArray,jacNewton);
        comps_Newton = BackendDAE.EQUATIONSYSTEM(eqnsNewton,varsNewton,jacNewton,jacTypeNewton);
        matching = BackendDAE.MATCHING(match1,match1,{comps_Newton});
        eqSystem = BackendDAE.EQSYSTEM(variables,eqArray,SOME(m_new),SOME(mT_new),matching,{});
        linearDAE = BackendDAE.DAE({eqSystem},shared);
        linearDAE1 = BackendDAEUtil.transformBackendDAE(linearDAE,SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())),NONE(),NONE());
        BackendDump.dumpBackendDAE(linearDAE1, "linearDAE1");
        BackendDAE.DAE({eqSystem},shared) = linearDAE1;
        BackendDAE.EQSYSTEM(orderedVars=variables,orderedEqs=eqArray,matching=matching) = eqSystem;
        BackendDAE.MATCHING(v1_new,v2_new,_) = matching;
        //(relaxedEqSystem,relaxedShared,_) = tearingSystemNew1(eqSystem,shared,{comps_Newton},false);
        print("\nrelaxedEqSystem\n");
        //BackendDump.printEqSystem(relaxedEqSystem);
        print("\n----end of linear system----\n");
        
        //-------------
        // clean v1,v2,m,mT
        v2_2 = arrayCreate(ll, 0);
        v2_2 = Util.arrayNCopy(v2_1, v2_2,ll);
        v1_2 = arrayCreate(ll, 0);
        v1_2 = Util.arrayNCopy(v1_1, v1_2,ll);
        BackendDAE.DAE({syst},shared) = dlow1_1;
        (syst,m_3,mT_3) = BackendDAEUtil.getIncidenceMatrix(syst,BackendDAE.NORMAL());
        dlow1_2 = BackendDAE.DAE({syst},shared);
        (v1_3,v2_3) = correctAssignments(v1_2,v2_2,residualeqns,tearingvars);
        // next Block
        (r,t,dlow_2,dlow1_3,m_4,mT_4,v1_3,v2_3,comps_1) = tearingSystem1(dlow_1,dlow1_2,m_3,mT_3,v1_2,v2_2,comps);
      then
        (residualeqns::r,tearingvars::t,dlow_2,dlow1_3,m_4,mT_4,v1_3,v2_3,comp_1::comps_1);
    case (dlow,dlow1,m,mT,v1,v2,comp::comps)
      equation
        print("\ntearing without relaxation\n");
        // block ?
        ll = listLength(comp);
        true = ll > 1;
        // get all interesting vars
        (tvars,crlst) = getTearingVars(m,v1,v2,comp,dlow);
        // try tearing
        (residualeqns,tearingvars,tearingeqns,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem2(dlow,dlow1,m,mT,v1,v2,comp,tvars,{},{},{},{},crlst);
        BackendDump.dumpTearing({residualeqns},{tearingvars});
        // clean v1,v2,m,mT
        v2_2 = arrayCreate(ll, 0);
        v2_2 = Util.arrayNCopy(v2_1, v2_2,ll);
        v1_2 = arrayCreate(ll, 0);
        v1_2 = Util.arrayNCopy(v1_1, v1_2,ll);
        BackendDAE.DAE({syst},shared) = dlow1_1;
        (syst,m_3,mT_3) = BackendDAEUtil.getIncidenceMatrix(syst,BackendDAE.NORMAL());
        dlow1_2 = BackendDAE.DAE({syst},shared);
        (v1_3,v2_3) = correctAssignments(v1_2,v2_2,residualeqns,tearingvars);
        // next Block
        (r,t,dlow_2,dlow1_3,m_4,mT_4,v1_3,v2_3,comps_1) = tearingSystem1(dlow_1,dlow1_2,m_3,mT_3,v1_2,v2_2,comps);
      then
        (residualeqns::r,tearingvars::t,dlow_2,dlow1_3,m_4,mT_4,v1_3,v2_3,comp_1::comps_1);
    case (dlow,dlow1,m,mT,v1,v2,comp::comps)
      equation
        // block ?
        ll = listLength(comp);
        false = ll > 1;
        // next Block
        (r,t,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comps_1) = tearingSystem1(dlow,dlow1,m,mT,v1,v2,comps);
      then
        ({0}::r,{0}::t,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp::comps_1);
  end matchcontinue;
end tearingSystem1;

public function getSubSystemDaeForVars "Returns a subsystem dae given a list of equations and a list of 
variables as indices."
  input list<Integer> eqnIndxLst;
  input list<Integer> varIndxLst;
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE outDae;
algorithm
  outDae:= match(eqnIndxLst,varIndxLst,dae)
  local 
    list<BackendDAE.Equation> eqnLst;
    list<BackendDAE.Var> varLst; 
    BackendDAE.EqSystem eqsys1;
    list<Integer> fixedIndex;
    case(_,_,_) equation
      BackendDAE.DAE(eqs=(eqsys1::_)) = dae;
       fixedIndex = List.map1r(eqnIndxLst,intAdd,-1);
       eqnLst = List.map1r(fixedIndex,BackendDAEUtil.equationNth,BackendEquation.daeEqns(eqsys1)); //daeArrayEqns equationNth
       varLst = List.map1r(varIndxLst,BackendVariable.getVarAt,BackendVariable.daeVars(eqsys1));
      then setDaeVarsAndEqs(dae,BackendEquation.listEquation(eqnLst),BackendVariable.listVar(varLst));
    case(_,_,_) equation
     //print("getSubSystemDaeForVars failed\n");
    then fail();
  end match;
end getSubSystemDaeForVars;

public function setDaeVarsAndEqs "
   note: this function destroys matching
"
  input BackendDAE.BackendDAE systIn;
  input BackendDAE.EquationArray newEqnsIn;
  input BackendDAE.Variables newVarsIn;
  output BackendDAE.BackendDAE sysOut;
algorithm
  sysOut:= match(systIn,newEqnsIn,newVarsIn) 
    local
       Option<BackendDAE.IncidenceMatrix> m;
       Option<BackendDAE.IncidenceMatrixT> mT;
       BackendDAE.Matching matching;
       BackendDAE.Shared shared;
       BackendDAE.EquationArray newEqns;
       BackendDAE.Variables newVars;
       list<BackendDAE.EqSystem> eqlist;
       BackendDAE.StateSets stateSets;
      case (BackendDAE.DAE(BackendDAE.EQSYSTEM(m=m,mT=mT,matching=matching,stateSets=stateSets)::eqlist,shared),newEqns,newVars)
        then 
           BackendDAE.DAE(BackendDAE.EQSYSTEM(newVars,newEqns,m,mT,matching,stateSets)::eqlist,shared);   
  end match;
end setDaeVarsAndEqs;  


protected function printEquationArr
  "prints an array of BackendDAE.Equations"
  input array<Option<BackendDAE.Equation>> inArr;
  input Integer indx;
  input Integer max;
algorithm
  _ := matchcontinue(inArr,indx,max)
  local
    BackendDAE.Equation entry;
    String str;
  case (_,_,_)
    equation
      true = (indx>max);
    then
      ();
  case (_,_,_)
    equation
      true = (indx<=max);
      SOME(entry) = arrayGet(inArr,indx);
      str = stringAppend("\neqArr",intString(indx));
      print(str);
      print("\n");
      BackendDump.printEquation(entry);
      printEquationArr(inArr,indx+1,max);
    then
      ();
  case (_,_,_)
    equation
      true = (indx<=max);
      NONE() = arrayGet(inArr,indx);
      print("NONE()");
      printEquationArr(inArr,indx+1,max);
    then
      ();
  end matchcontinue;
end printEquationArr;  
    

protected function equationToResidualFormArr
  "transforms an array with equations of the form a = b into an array with equations of the form a - b = 0"
  input array<Option<BackendDAE.Equation>> inOptEqArr;
  input Integer indx;
  input Integer max;
  output array<Option<BackendDAE.Equation>> outEqArr;
algorithm
  outEqArr := matchcontinue(inOptEqArr,indx,max)
  local
    BackendDAE.Equation entry,transEntry;
    Option<BackendDAE.Equation> transEntry1;
    array<Option<BackendDAE.Equation>> arr;
    DAE.Exp e1,e2;
  case (_,_,_)
    equation
      true = (indx>max);
    then
      inOptEqArr;
  case (_,_,_)
    equation
      true = (indx<=max);
      SOME(entry) = arrayGet(inOptEqArr,indx);
      BackendDAE.EQUATION(exp=e1,scalar=e2) = entry;
      transEntry = BackendEquation.equationToResidualForm(entry);
      transEntry1 = SOME(transEntry);
      arr = arrayUpdate(inOptEqArr,indx,transEntry1);
      outEqArr = equationToResidualFormArr(inOptEqArr,indx+1,max);
    then
      outEqArr;
  case (_,_,_)
    equation
      true = (indx<=max);
      outEqArr = equationToResidualFormArr(inOptEqArr,indx+1,max);
    then
      outEqArr;
  end matchcontinue;
end equationToResidualFormArr;

protected function newVariablesForNewton
  "creates the new variables for the Newton system"
  input Integer l;
  input list<DAE.ComponentRef> crefs;
  input BackendDAE.Variables inVars;
  output BackendDAE.Variables outVars;
algorithm
  outVars := match(l,crefs,inVars)
  local
    BackendDAE.Var var;
    DAE.ComponentRef cref;
    list<DAE.ComponentRef> rest;
    BackendDAE.Variables variables,variables1;
  case (_,cref::rest,_)
    equation
      var = BackendDAE.VAR(cref, BackendDAE.VARIABLE(),DAE.BIDIR(),DAE.NON_PARALLEL(),DAE.T_REAL_DEFAULT,NONE(),NONE(),{},
                            DAE.emptyElementSource,
                            NONE(),NONE(),DAE.NON_CONNECTOR());
      variables1 = BackendVariable.addVar(var,inVars);
      variables = newVariablesForNewton(l,rest,variables1);
    then
      variables;
  case (_,{},_)
    then
      inVars;
  end match;
end newVariablesForNewton;


protected function createCrefLstForNewton
  "creates a list<DAE.ComponentRef> with the length of the number of tearing variables"
  input Integer l;  //number of tVars
  input Integer indx;
  input list<DAE.ComponentRef> inRefLst;
  output list<DAE.ComponentRef> outRefLst;
algorithm
  outRefLst := matchcontinue(l,indx,inRefLst)
  local
    String str;
    DAE.ComponentRef cref;
    list<DAE.ComponentRef> refLst;
  case (_,_,_)
    equation
      true = (indx>l);
    then
     inRefLst;
  case (_,_,_)
    equation
      true = (indx<=l);
      str = stringAppend("NV",intString(indx));
      cref = ComponentReference.makeCrefIdent(str, DAE.T_REAL_DEFAULT, {});  //NV = NewtonVariable
      refLst = listAppend(inRefLst,{cref});
      outRefLst = createCrefLstForNewton(l,indx+1,refLst);
    then
      outRefLst;
  end matchcontinue; 
end createCrefLstForNewton;

protected function arrLstCrefIndex
  "array<DAE.ComponentRef> --> array<list<BackendDAE.CrefIndex>>"
  input array<DAE.ComponentRef> inArr;
  input Integer indx;
  input array<list<BackendDAE.CrefIndex>> inArrLst;
  output array<list<BackendDAE.CrefIndex>> outArrLst;
algorithm
  outArrLst := matchcontinue(inArr,indx,inArrLst)
  local
    BackendDAE.CrefIndex entry;
    DAE.ComponentRef entryCR;
  case (_,_,_)
    equation
      true = (indx>arrayLength(inArrLst));
    then
      inArrLst;
  case (_,_,_)
    equation
      true = (indx <= arrayLength(inArrLst));
      entryCR = arrayGet(inArr,indx);
      entry = BackendDAE.CREFINDEX(entryCR,indx);
      outArrLst = arrayUpdate(inArrLst,indx,{entry});
      outArrLst = arrLstCrefIndex(inArr,indx+1,outArrLst);
    then
      outArrLst;
  case (_,_,_)
    then
      fail();
  end matchcontinue;
end arrLstCrefIndex;

protected function expToEquationArr
  "transforms an array<DAE.Exp> into an array<BackendDAE.Equation>"
  input array<DAE.Exp> inExpArr;
  input Integer indx;
  input array<BackendDAE.Equation> inEqArr;
  output array<BackendDAE.Equation> outEqArr;
algorithm
  outEqArr := matchcontinue(inExpArr,indx,inEqArr)
  local
    DAE.Exp entryExp;
    BackendDAE.Equation entry;
    array<BackendDAE.Equation> eqArr,eqArr1;
  case (_,_,_)
    equation
      false = (indx<=arrayLength(inEqArr));
    then
      inEqArr;
  case (_,_,_)
    equation
      true = (indx<=arrayLength(inEqArr));
      entryExp = arrayGet(inExpArr,indx);
      entry = BackendDAE.EQUATION(entryExp,DAE.RCONST(0.0),DAE.emptyElementSource,false);  //DAE.RCONST???
      eqArr = arrayUpdate(inEqArr,indx,entry);
      eqArr1 = expToEquationArr(inExpArr,indx+1,eqArr);
    then
      eqArr1;
  end matchcontinue;
end expToEquationArr;

protected function equationToExpArr
  "transforms an array<Option<BackendDAE.Equation>> into an array<DAE.Exp>"
  input array<Option<BackendDAE.Equation>> inArr;
  input Integer indx;
  input array<DAE.Exp> arr;
  output array<DAE.Exp> outArr;
algorithm
  outArr := matchcontinue(inArr,indx,arr)
  local
    Option<BackendDAE.Equation> optEq;
    BackendDAE.Equation eq;
    DAE.Exp e;
    array<DAE.Exp> arr1,arr2;
  case (_,_,_)
    equation
      true = (indx>arrayLength(arr));
    then
      arr;
  case (_,_,_)
    equation
      true = (indx<=arrayLength(arr));
      optEq = arrayGet(inArr,indx);
      SOME(eq) = optEq;
      BackendDAE.EQUATION(exp=e) = eq;
      arr1 = arrayUpdate(arr,indx,e);
      arr2 = equationToExpArr(inArr,indx+1,arr1);
    then
      arr2;
  case (_,_,_)
    equation
      true = (indx<=arrayLength(arr));
      optEq = arrayGet(inArr,indx);
      SOME(eq) = optEq;
      BackendDAE.RESIDUAL_EQUATION(exp=e) = eq;
      arr1 = arrayUpdate(arr,indx,e);
      arr2 = equationToExpArr(inArr,indx+1,arr1);
    then
      arr2;
  case (_,_,_)
    equation
      true = (indx<=arrayLength(arr));
      optEq = arrayGet(inArr,indx);
      NONE() = optEq;
      e = DAE.RCONST(0.0);
      arr1 = arrayUpdate(arr,indx,e);
      arr2 = equationToExpArr(inArr,indx+1,arr1);
    then
      arr2;
  end matchcontinue;
end equationToExpArr;

protected function buildLinSystForNewton
  "builds the system f'(x)*dx = f(x) <-> f'(x)*dx-f(x) = 0, f residual equations, x tearing variables"
  input array<DAE.Exp> lhsArr;
  input array<DAE.Exp> rhsArr;
  input Integer indx;
  input array<DAE.Exp> expArr;
  output array<DAE.Exp> outExpArr;
algorithm
  outExpArr := matchcontinue(lhsArr,rhsArr,indx,expArr)
    local
      DAE.Exp lhs,rhs,outExp,outExp1;
    case (_,_,_,_)
      equation
        true = (indx<=arrayLength(lhsArr));
        lhs = arrayGet(lhsArr,indx);
        rhs = arrayGet(rhsArr,indx);
        outExp1 = Expression.makeDifference(lhs,rhs);
        (outExp,_) = ExpressionSimplify.simplify(outExp1); 
        outExpArr = arrayUpdate(expArr,indx,outExp);
        outExpArr = buildLinSystForNewton(lhsArr,rhsArr,indx+1,outExpArr);
      then
        outExpArr;
    case (_,_,_,_)
      equation
        true = (indx>arrayLength(lhsArr));
      then
        expArr;
  end matchcontinue;
end buildLinSystForNewton;

protected function matrixVectorMultiplication
  input list<tuple<Integer, Integer, BackendDAE.Equation>> jac;
  input Integer row;
  input Integer col;  //column
  input BackendDAE.Variables vars;
  input Integer size;
  input array<DAE.Exp> inExpArr;
  input list<DAE.ComponentRef> inLstRef;
  output array<DAE.Exp> outExp; 
  output list<DAE.ComponentRef> outLstRef;
algorithm
  (outExp,outLstRef) := matchcontinue(jac,row,col,vars,size,inExpArr,inLstRef)
  local
    DAE.Exp e,exp1,eqExp,varExp;
    array<DAE.Exp> expArr;
    DAE.ComponentRef cr;
    BackendDAE.Equation eq;
    list<DAE.ComponentRef> varcrefs; 
  case (_,_,_,_,_,_,_)
    equation
      true = intEq(col,1);
      false = intLt(size,col);  //col<=size
      false = intLt(size,row);  //row<=size
      varcrefs = BackendVariable.getAllCrefFromVariables(vars);
      cr = listGet(varcrefs,col);
      varExp = Expression.crefExp(cr);
      eq = getEqFromTupleLst(jac,row,col);  //entry of the jacobian
      BackendDAE.RESIDUAL_EQUATION(exp=eqExp) = eq;
      true = Expression.isZero(eqExp);
      (expArr,varcrefs) = matrixVectorMultiplication(jac,row,col+1,vars,size,inExpArr,varcrefs); 
    then
      (expArr,varcrefs);
  case (_,_,_,_,_,_,_)
    equation
      true = intEq(col,1);
      false = intLt(size,col);  //col<=size
      false = intLt(size,row);  //row<=size
      varcrefs = BackendVariable.getAllCrefFromVariables(vars);
      cr = listGet(varcrefs,col);
      varExp = Expression.crefExp(cr);
      eq = getEqFromTupleLst(jac,row,col);  //entry of the jacobian
      BackendDAE.RESIDUAL_EQUATION(exp=eqExp) = eq;
      false = Expression.isZero(eqExp);
      exp1 = Expression.expMul(eqExp,varExp);
      expArr = arrayUpdate(inExpArr,row,exp1);
      (expArr,varcrefs) = matrixVectorMultiplication(jac,row,col+1,vars,size,expArr,varcrefs); 
    then
      (expArr,varcrefs);
  case (_,_,_,_,_,_,_)
    equation
      true = intGt(col,size);  //col>size
      (expArr,varcrefs) = matrixVectorMultiplication(jac,row+1,1,vars,size,inExpArr,inLstRef);
    then
      (expArr,varcrefs);
  case (_,_,_,_,_,_,_)
    equation
      false = intEq(col,1);
      false = intLt(size,col);  //col<=size
      false = intLt(size,row);  //row<=size
      varcrefs = BackendVariable.getAllCrefFromVariables(vars);
      cr = listGet(varcrefs,col);
      varExp = Expression.crefExp(cr);
      eq = getEqFromTupleLst(jac,row,col);
      BackendDAE.RESIDUAL_EQUATION(exp=eqExp) = eq;
      false = Expression.isZero(eqExp);
      e = arrayGet(inExpArr,row);
      exp1 = Expression.expAdd(e,Expression.expMul(eqExp,varExp));
      expArr = arrayUpdate(inExpArr,row,exp1);
      (expArr,varcrefs) = matrixVectorMultiplication(jac,row,col+1,vars,size,expArr,varcrefs); 
    then
      (expArr,inLstRef);
  case (_,_,_,_,_,_,_)
    equation
      false = intEq(col,1);
      false = intLt(size,col);  //col<=size
      false = intLt(size,row);  //row<=size
      varcrefs = BackendVariable.getAllCrefFromVariables(vars);
      cr = listGet(varcrefs,col);
      varExp = Expression.crefExp(cr);
      eq = getEqFromTupleLst(jac,row,col);
      BackendDAE.RESIDUAL_EQUATION(exp=eqExp) = eq;
      true = Expression.isZero(eqExp);
      (expArr,varcrefs) = matrixVectorMultiplication(jac,row,col+1,vars,size,inExpArr,varcrefs);
    then
      (expArr,inLstRef);
  case (_,_,_,_,_,_,_)
    equation
      true = intGt(row,size);  //row>size
    then
      (inExpArr,inLstRef);
  case (_,_,_,_,_,_,_)
    then
      fail();
  end matchcontinue;
end matrixVectorMultiplication;

protected function getEqFromTupleLst
  "gets the equation of a list of tuple<Integer, Integer, BackendDAE.Equation> for two given integers"
  input list<tuple<Integer, Integer, BackendDAE.Equation>> inTuple;
  input Integer r;
  input Integer c;
  output BackendDAE.Equation outEq;
algorithm
  outEq := matchcontinue(inTuple,r,c)
  local
    list<tuple<Integer, Integer, BackendDAE.Equation>> rest;
    Integer i1,i2;
    BackendDAE.Equation eq;
  case ((i1,i2,eq)::rest,_,_)
    equation
      true = intEq(i1,r);  //i1 = r
      true = intEq(i2,c);  //i2 = c
    then
      eq;
  case ((i1,i2,eq)::rest,_,_)
    equation
      false = intEq(i1,r);  //i1 <>r
      eq = getEqFromTupleLst(rest,r,c);
    then
      eq;
  case ((i1,i2,eq)::rest,_,_)
    equation
      false = intEq(i2,c);  //i2 <>c
      eq = getEqFromTupleLst(rest,r,c);
    then
      eq;
  case ({},_,_)
    then
      BackendDAE.RESIDUAL_EQUATION(DAE.RCONST(0.0),DAE.emptyElementSource,false);  //(r,c) does not appear in jac
  end matchcontinue;
end getEqFromTupleLst;

protected function correctAssignments
" function: correctAssignments
  Correct the assignments"
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<Integer> inRLst;
  input list<Integer> inTLst;
  output array<Integer> outV1;
  output array<Integer> outV2;
algorithm
  (outV1,outV2):=
  match (inV1,inV2,inRLst,inTLst)
    local
      array<Integer> v1,v2,v1_1,v2_1,v1_2,v2_2;
      list<Integer> rlst,tlst;
      Integer r,t;
    case (v1,v2,{},{}) then (v1,v2);
    case (v1,v2,r::rlst,t::tlst)
      equation
         v1_1 = arrayUpdate(v1,t,r);
         v2_1 = arrayUpdate(v2,r,t);
         (v1_2,v2_2) = correctAssignments(v1_1,v2_1,rlst,tlst);
      then
        (v1_2,v2_2);
  end match;
end correctAssignments;

protected function getTearingVars
" function: getTearingVars
  Substracts all interesting vars for tearing"
  input BackendDAE.IncidenceMatrix inM;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<Integer> inComp;
  input BackendDAE.BackendDAE inDlow;
  output list<Integer> outVarLst;
  output list<DAE.ComponentRef> outCrLst;
algorithm
  (outVarLst,outCrLst):=
  match (inM,inV1,inV2,inComp,inDlow)
    local
      BackendDAE.IncidenceMatrix m;
      array<Integer> v1,v2;
      Integer c,v;
      list<Integer> comp,varlst;
      BackendDAE.BackendDAE dlow;
      DAE.ComponentRef cr;
      list<DAE.ComponentRef> crlst;
      BackendDAE.Variables ordvars;
    case (m,v1,v2,{},dlow) then ({},{});
    case (m,v1,v2,c::comp,dlow as BackendDAE.DAE(eqs=BackendDAE.EQSYSTEM(orderedVars = ordvars)::{}))
      equation
        v = v2[c];
        BackendDAE.VAR(varName = cr) = BackendVariable.getVarAt(ordvars, v);
        (varlst,crlst) = getTearingVars(m,v1,v2,comp,dlow);
      then
        (v::varlst,cr::crlst);
  end match;
end getTearingVars;

protected function tearingSystem2
" function: tearingSystem
  This function selects a tearing variable. The variable nodes (V-nodes) are weighted with the sum of the weights of 
  its incident edges. The edges are weighted as the inverse of the vertex degree of its incident equation node
  (E-node). The V-node with largest weight is chosen."
  input BackendDAE.BackendDAE inDlow;
  input BackendDAE.BackendDAE inDlow1;
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<Integer> inComp;
  input list<Integer> inVars;
  input list<Integer> inExclude;
  input list<Integer> inResEqns;
  input list<Integer> inTearVars;
  input list<Integer> inTearEqns;
  input list<DAE.ComponentRef> inCrlst;
  output list<Integer> outResEqns;
  output list<Integer> outTearVars;
  output list<Integer> outTearEqns;
  output BackendDAE.BackendDAE outDlow;
  output BackendDAE.BackendDAE outDlow1;
  output BackendDAE.IncidenceMatrix outM;
  output BackendDAE.IncidenceMatrixT outMT;
  output array<Integer> outV1;
  output array<Integer> outV2;
  output list<Integer> outComp;
algorithm
  (outResEqns,outTearVars,outTearEqns,outDlow,outDlow1,outM,outMT,outV1,outV2,outComp):=
  matchcontinue (inDlow,inDlow1,inM,inMT,inV1,inV2,inComp,inVars,inExclude,inResEqns,inTearVars,inTearEqns,inCrlst)
    local
      BackendDAE.BackendDAE dlow,dlow_1,dlow1,dlow1_1;
      BackendDAE.IncidenceMatrix m,m_1;
      BackendDAE.IncidenceMatrixT mT,mT_1;
      array<Integer> v1,v2,v1_1,v2_1;
      list<Integer> comp,comp_1,exclude,vars;
      Integer tearVar;
      list<Integer> tearingvars,residualeqns,tearingvars_1,residualeqns_1,tearingeqns,tearingeqns_1;
      list<DAE.ComponentRef> crlst;
      list<Integer> eqns,eqns_1;
      BackendDAE.EqSystem syst;
      tuple<Real,Integer> tupl;
       
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,vars,exclude,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        tupl = tearingVariable(m,mT,vars,comp,0.0,0,exclude);
        (_,tearVar) = tupl;
        true = tearVar > 0;
        eqns = mT[tearVar];  //gets all E-nodes incident to the tearing variable
        eqns_1 = eqns;
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem3(dlow,dlow1,m,mT,v1,v2,comp,eqns_1,{},tearVar,residualeqns,tearingvars,tearingeqns,crlst);
    then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1);
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,vars,exclude,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        true = (listLength(tearingvars)==0);  //until now tearing was not used
        tupl = tearingVariable(m,mT,vars,comp,0.0,0,exclude);
        (_,tearVar) = tupl;
        true = tearVar > 0;
        eqns = mT[tearVar];  //gets all E-nodes incident to the tearing variable
        eqns_1 = eqns;
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem3(dlow,dlow1,m,mT,v1,v2,comp,eqns_1,{},tearVar,residualeqns,tearingvars,tearingeqns,crlst);
    then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1);
   
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,vars,exclude,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        tupl = tearingVariable(m,mT,vars,comp,0.0,0,exclude);
        (_,tearVar) = tupl;
        true = tearVar > 0;
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem2(dlow,dlow1,m,mT,v1,v2,comp,vars,tearVar::exclude,residualeqns,tearingvars,tearingeqns,crlst);
      then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1);
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,vars,exclude,residualeqns,tearingvars,tearingeqns,_)
      equation
        tupl = tearingVariable(m,mT,vars,comp,0.0,0,exclude);
        (_,tearVar) = tupl;
        false = tearVar > 0;
        Debug.fcall(Flags.TEARING_DUMP, print, "Select tearVar BackendDAE.Equation failed\n");
      then
        fail();
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,vars,exclude,residualeqns,tearingvars,tearingeqns,_)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print, "Select tearing variable failed!\n");
      then
        fail();   
  end matchcontinue;
end tearingSystem2;

protected function tearingSystem3
" function: tearingSystem3
  This function selects a residual equation. It chooses the one incident to the tearing variable with 
  largest vertex degree." 
  input BackendDAE.BackendDAE inDlow;
  input BackendDAE.BackendDAE inDlow1;
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<Integer> inComp;
  input list<Integer> inEqs;
  input list<Integer> inExclude;
  input Integer inTearVar;
  input list<Integer> inResEqns;
  input list<Integer> inTearVars;
  input list<Integer> inTearEqns;
  input list<DAE.ComponentRef> inCrlst;
  output list<Integer> outResEqns;
  output list<Integer> outTearVars;
  output list<Integer> outTearEqns;
  output BackendDAE.BackendDAE outDlow;
  output BackendDAE.BackendDAE outDlow1;
  output BackendDAE.IncidenceMatrix outM;
  output BackendDAE.IncidenceMatrixT outMT;
  output array<Integer> outV1;
  output array<Integer> outV2;
  output list<Integer> outComp;
algorithm
  (outResEqns,outTearVars,outTearEqns,outDlow,outDlow1,outM,outMT,outV1,outV2,outComp):=
  matchcontinue (inDlow,inDlow1,inM,inMT,inV1,inV2,inComp,inEqs,inExclude,inTearVar,inResEqns,inTearVars,inTearEqns,inCrlst)
    local
      BackendDAE.BackendDAE dlow,dlow_1,dlow_2,dlow_3,dlow1,dlow1_1,dlow1_2,dlowc,dlowc1;
      BackendDAE.IncidenceMatrix m,m_1,m_2,m_3;
      BackendDAE.IncidenceMatrixT mT,mT_1,mT_2,mT_3;
      array<Integer> v1,v2,v1_1,v2_1,v1_2,v2_2;
      BackendDAE.StrongComponents comps;
      list<list<Integer>> comps_1,comps_2,onecomp,morecomps;
      list<Integer> comp,comp_1,comp_2,exclude,cmops_flat,onecomp_flat,othereqns,resteareqns,eqs;
      Integer tearingvar,residualeqn,compcount,tearingeqnid;
      list<Integer> residualeqns,residualeqns_1,tearingvars,tearingvars_1,tearingeqns,tearingeqns_1;
      DAE.ComponentRef cr,crt;
      list<DAE.ComponentRef> crlst;

      BackendDAE.Variables ordvars,vars_1,ordvars1;
      BackendDAE.EquationArray eqns, eqns_1, eqns_2,eqns1,eqns1_1;
      DAE.Exp eqn,scalar,rhs,expCref,expR,expR1;


      DAE.ElementSource source;
      BackendDAE.Var var;
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;
      
      tuple<Real,Integer> tupl;
      
      array<Option<BackendDAE.Equation>> equOptArr1,equOptArr;
      
      BackendDAE.Equation eq,entry,entry1,entry1_1;
      Boolean diffed;
      BackendDAE.StateSets stateSets;
    
    case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        true = (listLength(residualeqns)<>0);  //there exist alreay chosen residual equations
        tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        true = residualeqn > 0;
        // copy dlow
        dlowc = BackendDAEUtil.copyBackendDAE(dlow);
        BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=ordvars,orderedEqs=eqns)::{},shared) = dlowc;
        BackendDAE.EQUATION_ARRAY(equOptArr=equOptArr) = eqns;
        dlowc1 = BackendDAEUtil.copyBackendDAE(dlow1);
        BackendDAE.DAE(eqs = BackendDAE.EQSYSTEM(orderedVars=ordvars1,orderedEqs=eqns1)::{}) = dlowc1;
        BackendDAE.EQUATION_ARRAY(equOptArr=equOptArr1) = eqns1;
        // add Tearing Var
        var = BackendVariable.getVarAt(ordvars, tearingvar);
        cr = BackendVariable.varCref(var);
        crt = ComponentReference.prependStringCref("tearingresidual_",cr);
        vars_1 = BackendVariable.addVar(BackendDAE.VAR(crt, BackendDAE.VARIABLE(),DAE.BIDIR(),DAE.NON_PARALLEL(),DAE.T_REAL_DEFAULT,NONE(),NONE(),{},DAE.emptyElementSource,
                            SOME(DAE.VAR_ATTR_REAL(NONE(),NONE(),NONE(),(NONE(),NONE()),NONE(),SOME(DAE.BCONST(true)),NONE(),NONE(),NONE(),NONE(),NONE(),NONE(),NONE(),NONE())),
                            NONE(),DAE.NON_CONNECTOR()), ordvars);
        // replace in residual equation orgvar with Tearing Var
        BackendDAE.EQUATION(eqn,scalar,source,diffed) = BackendDAEUtil.equationNth(eqns,residualeqn-1);
        // (eqn_1,replace) =  Expression.replaceExp(eqn,Expression.crefExp(cr),Expression.crefExp(crt));
        // (scalar_1,replace1) =  Expression.replaceExp(scalar,Expression.crefExp(cr),Expression.crefExp(crt));
        // true = replace + replace1 > 0;

        // Add Residual eqn
        rhs = Expression.crefExp(crt);
        eq = BackendDAEUtil.equationNth(eqns,residualeqn-1);
        entry = BackendEquation.equationToResidualForm(eq);
        BackendDAE.RESIDUAL_EQUATION(exp=expR) = entry;
        expR1 =  Expression.makeDifference(expR,rhs);
        entry1 = BackendDAE.EQUATION(expR1,DAE.RCONST(0.0),source,false);
        entry1_1 = BackendDAE.EQUATION(expR,DAE.RCONST(0.0),source,false);
        eqns_1 = BackendEquation.equationSetnth(eqns,residualeqn-1,entry1);
        eqns1_1 = BackendEquation.equationSetnth(eqns1,residualeqn-1,entry1_1);
        // add equation to calc org var
        expCref = Expression.crefExp(cr);
        eqns_2 = BackendEquation.equationAdd(BackendDAE.EQUATION(DAE.CALL(Absyn.IDENT("tearing"),
                          {},DAE.callAttrBuiltinReal),
                          expCref, DAE.emptyElementSource,false),eqns_1);

        tearingeqnid = BackendDAEUtil.equationSize(eqns_2);
        dlow_1 = BackendDAE.DAE(BackendDAE.EQSYSTEM(vars_1,eqns_2,NONE(),NONE(),BackendDAE.NO_MATCHING(),{})::{},shared);
        dlow1_1 = BackendDAE.DAE(BackendDAE.EQSYSTEM(ordvars1,eqns1_1,NONE(),NONE(),BackendDAE.NO_MATCHING(),{})::{},shared);
        // try causalisation
        (dlow_2 as BackendDAE.DAE(eqs=BackendDAE.EQSYSTEM(m=SOME(m_2),mT=SOME(mT_2),matching=BackendDAE.MATCHING(v1_1,v2_1,comps))::{})) = BackendDAEUtil.transformBackendDAE(dlow_1,SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())),NONE(),NONE());
        comps_1 = List.map(comps,getEqnIndxFromComp);
        // check strongComponents and split it into two lists: len(comp)==1 and len(comp)>1
        (morecomps,onecomp) = splitComps(comps_1);
        // try to solve the equations
        onecomp_flat = List.flatten(onecomp);
        // remove residual equations and tearing eqns
        resteareqns = listAppend(tearingeqnid::tearingeqns,residualeqn::residualeqns);
        othereqns = List.select1(onecomp_flat,List.notMember,resteareqns);
         // if we have not make alle equations causal select next residual equation
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_3,dlow1_2,m_3,mT_3,v1_2,v2_2,comps_2,compcount) = tearingSystem4(dlow_2,dlow1_1,m_2,mT_2,v1_1,v2_1,comps_1,residualeqn::residualeqns,tearingvar::tearingvars,tearingeqnid::tearingeqns,comp,0,crlst);
        // check
        true = ((listLength(residualeqns_1) > listLength(residualeqns)) and
                (listLength(tearingvars_1) > listLength(tearingvars)) ) or (compcount == 0);
        // get specifig comps
        cmops_flat = List.flatten(comps_2);
        comp_2 = List.select1(cmops_flat,listMember,comp);
      then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_3,dlow1_2,m_3,mT_3,v1_2,v2_2,comp_2);
   case (dlow as BackendDAE.DAE(eqs={syst}),dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        true = (listLength(residualeqns)==0);  //until now no residual equations have been used
        tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        true = residualeqn > 0;
        // copy dlow
        dlowc = BackendDAEUtil.copyBackendDAE(dlow);
        BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=ordvars,orderedEqs=eqns)::{},shared) = dlowc;
        dlowc1 = BackendDAEUtil.copyBackendDAE(dlow1);
        BackendDAE.DAE(eqs = BackendDAE.EQSYSTEM(orderedVars=ordvars1,orderedEqs=eqns1)::{}) = dlowc1;
        // add Tearing Var
        var = BackendVariable.getVarAt(ordvars, tearingvar);
        cr = BackendVariable.varCref(var);
        crt = ComponentReference.prependStringCref("tearingresidual_",cr);
        vars_1 = BackendVariable.addVar(BackendDAE.VAR(crt, BackendDAE.VARIABLE(),DAE.BIDIR(),DAE.NON_PARALLEL(),DAE.T_REAL_DEFAULT,NONE(),NONE(),{},DAE.emptyElementSource,
                            SOME(DAE.VAR_ATTR_REAL(NONE(),NONE(),NONE(),(NONE(),NONE()),NONE(),SOME(DAE.BCONST(true)),NONE(),NONE(),NONE(),NONE(),NONE(),NONE(),NONE(),NONE())),
                            NONE(),DAE.NON_CONNECTOR()), ordvars);
        // replace in residual equation orgvar with Tearing Var
        BackendDAE.EQUATION(eqn,scalar,source,diffed) = BackendDAEUtil.equationNth(eqns,residualeqn-1);
        // true = replace + replace1 > 0;

        // Add Residual eqn
        rhs = Expression.crefExp(crt);
        
        eq = BackendDAEUtil.equationNth(eqns,residualeqn-1);
        entry = BackendEquation.equationToResidualForm(eq);
        BackendDAE.RESIDUAL_EQUATION(exp=expR) = entry;
        expR1 =  Expression.makeDifference(expR,rhs);
        entry1 = BackendDAE.EQUATION(expR1,DAE.RCONST(0.0),source,false);
        entry1_1 = BackendDAE.EQUATION(expR,DAE.RCONST(0.0),source,false);
        eqns_1 = BackendEquation.equationSetnth(eqns,residualeqn-1,entry1);
        eqns1_1 = BackendEquation.equationSetnth(eqns1,residualeqn-1,entry1_1);
        //eqns1_1 = BackendEquation.equationSetnth(eqns1,residualeqn-1,BackendDAE.EQUATION(DAE.BINARY(eqn,DAE.SUB(DAE.T_REAL_DEFAULT),scalar),DAE.RCONST(0.0),source));
        // add equation to calc org var
        expCref = Expression.crefExp(cr);
        eqns_2 = BackendEquation.equationAdd(BackendDAE.EQUATION(DAE.CALL(Absyn.IDENT("tearing"),
                          {},DAE.callAttrBuiltinReal),
                          expCref, DAE.emptyElementSource,false),eqns_1);

        tearingeqnid = BackendDAEUtil.equationSize(eqns_2);
        dlow_1 = BackendDAE.DAE(BackendDAE.EQSYSTEM(vars_1,eqns_2,NONE(),NONE(),BackendDAE.NO_MATCHING(),{})::{},shared);
        dlow1_1 = BackendDAE.DAE(BackendDAE.EQSYSTEM(ordvars1,eqns1_1,NONE(),NONE(),BackendDAE.NO_MATCHING(),{})::{},shared);
        // try causalisation
        (dlow_2 as BackendDAE.DAE(eqs=BackendDAE.EQSYSTEM(m=SOME(m_2),mT=SOME(mT_2),matching=BackendDAE.MATCHING(v1_1,v2_1,comps))::{})) = BackendDAEUtil.transformBackendDAE(dlow_1,SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())),NONE(),NONE());
        comps_1 = List.map(comps,getEqnIndxFromComp);
        // check strongComponents and split it into two lists: len(comp)==1 and len(comp)>1
        (morecomps,onecomp) = splitComps(comps_1);
        // try to solve the equations
        onecomp_flat = List.flatten(onecomp);
        // remove residual equations and tearing eqns
        resteareqns = listAppend(tearingeqnid::tearingeqns,residualeqn::residualeqns);
        othereqns = List.select1(onecomp_flat,List.notMember,resteareqns);
         // if we have not make alle equations causal select next residual equation
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_3,dlow1_2,m_3,mT_3,v1_2,v2_2,comps_2,compcount) = tearingSystem4(dlow_2,dlow1_1,m_2,mT_2,v1_1,v2_1,comps_1,residualeqn::residualeqns,tearingvar::tearingvars,tearingeqnid::tearingeqns,comp,0,crlst);
        // check
        true = ((listLength(residualeqns_1) > listLength(residualeqns)) and
                (listLength(tearingvars_1) > listLength(tearingvars)) ) or (compcount == 0);
        // get specifig comps
        cmops_flat = List.flatten(comps_2);
        comp_2 = List.select1(cmops_flat,listMember,comp);
      then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_3,dlow1_2,m_3,mT_3,v1_2,v2_2,comp_2);
    case (dlow,dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        true = (listLength(residualeqns)<>0);  //there exist alreay chosen residual equations
       tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        true = residualeqn > 0;
        // clear errors
        Error.clearMessages();
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem3(dlow,dlow1,m,mT,v1,v2,comp,eqs,residualeqn::exclude,tearingvar,residualeqns,tearingvars,tearingeqns,crlst);
      then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1);
    case (dlow,dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,crlst)
      equation
        true = (listLength(residualeqns)==0);  //until now no residual equations have been used
        tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        true = residualeqn > 0;
        // clear errors
        Error.clearMessages();
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem3(dlow,dlow1,m,mT,v1,v2,comp,eqs,residualeqn::exclude,residualeqn,residualeqns,tearingvars,tearingeqns,crlst);
      then
        (residualeqns_1,tearingvars_1,tearingeqns_1,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1);
    case (dlow,dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,_)
      equation
        true = (listLength(residualeqns)<>0);  //there exist alreay chosen residual equations
        tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        false = residualeqn > 0;
        // clear errors
        Error.clearMessages();
        Debug.fcall(Flags.TEARING_DUMP, print, "Select Tearing BackendDAE.Var failed\n");
      then
        fail();
    case (dlow,dlow1,m,mT,v1,v2,comp,eqs,exclude,tearingvar,residualeqns,tearingvars,tearingeqns,_)
      equation
        true = (listLength(residualeqns)==0);  //until now no residual equations have been used
        tupl = residualEquation(m,mT,eqs,comp,0.0,0,exclude,tearingvar);
        (_,residualeqn) = tupl;
        false = residualeqn > 0;
        // clear errors
        Error.clearMessages();
        Debug.fcall(Flags.TEARING_DUMP, print, "Select Tearing BackendDAE.Var failed\n");
      then
        fail();
  end matchcontinue;
end tearingSystem3;

protected function residualEquation
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input list<Integer> inLst;
  input list<Integer> inComp;
  input Real inMax;
  input Integer inEq;
  input list<Integer> inExclude;
  input Integer inTearVar;
  output tuple<Real,Integer> outTupl;
algorithm
  outTupl := matchcontinue(inM,inMT,inLst,inComp,inMax,inEq,inExclude,inTearVar)
  local
    BackendDAE.IncidenceMatrix m;
    BackendDAE.IncidenceMatrixT mt;
    list<Integer> rest,comp,exclude;
    Integer e,eq,tearVar;
    Real max;
    //Real e2,t;
    list<tuple<Real,Integer>> tupls;
    tuple<Real,Integer> tupl;
  case (m,mt,e::rest,comp,max,eq,exclude,tearVar)
    equation
      tupls = edgeDegree(mt[tearVar],{(0.0,0)},m);
      tupl = getMaxFromListWithTuples(tupls,(0.0,0),exclude);
    then
      tupl;
  case (_,_,_,_,_,_,_,_)
    equation
      Debug.fcall(Flags.TEARING_DUMP, print, "Select residual equation failed!\n");
    then
      fail();        
  end matchcontinue;
end residualEquation;

protected function edgeDegree
  input list<Integer> inLst;
  input list<tuple<Real,Integer>> inTupls;
  input BackendDAE.IncidenceMatrix inM;
  output list<tuple<Real,Integer>> outTupls;
algorithm
  outTupls := matchcontinue(inLst,inTupls,inM)
  local
    BackendDAE.IncidenceMatrix m;
    Integer e,deg;
    list<Integer> rest,incLst;
    Real degReal;
    tuple<Real,Integer> tupl;
    list<tuple<Real,Integer>> tupls,tupls1;
  case (e::rest,tupls,m)
    equation
      true = (e > 0);
       incLst = m[e];
       deg = listLength(incLst);
       degReal = intReal(deg);
       tupl = (degReal,e);
       tupls1 = listAppend(tupls,{tupl});
       tupls = edgeDegree(rest,tupls1,m);
    then
      tupls;
  case (e::rest,tupls,m)
    equation
      false = (e > 0);
      tupls = edgeDegree(rest,tupls,m);
    then
      tupls;
  case ({},tupls,m) then tupls;
  case (_,_,_)
    then
      fail();        
  end matchcontinue;
end edgeDegree;

protected function getMaxFromListWithTuples
"gets the argument v such that f(v) is maximal; list<tuple> = {(f,v)}"
  input list<tuple<Real,Integer>> inLst;
  input tuple<Real,Integer> oldTupl;
  input list<Integer> inExclude;
  output tuple<Real,Integer> outTupl;
algorithm
  outTupl := matchcontinue(inLst,oldTupl,inExclude)
  local
    list<tuple<Real,Integer>> rest;
    Real weight,oldWeight;
    Integer var,oldVar;
    tuple<Real,Integer> tupl;
    list<Integer> exclude;
  case ((weight,var)::rest,(oldWeight,oldVar),exclude)
    equation
      true = (var > 0);
      false = listMember(var,exclude);  //v(2) does not belong to the list with excluded vars
      true = (weight >. oldWeight);
      tupl = getMaxFromListWithTuples(rest,(weight,var),exclude);
    then
      tupl;
  case ((weight,var)::rest,(oldWeight,oldVar),exclude)
    equation
      true = (var > 0);
      false = listMember(var,exclude);
      false = (weight >. oldWeight);
      tupl = getMaxFromListWithTuples(rest,(oldWeight,oldVar),exclude);
    then
      tupl;
  case ({},_,exclude)
    equation
    then
      oldTupl;
  case ((weight,var)::rest,_,exclude)
    equation
      true = (var > 0);
      true = listMember(var,exclude);
      tupl = getMaxFromListWithTuples(rest,oldTupl,exclude);
    then
      tupl;
  case ((weight,var)::rest,_,exclude)
    equation
      false = (var > 0);
      tupl = getMaxFromListWithTuples(rest,oldTupl,exclude);
    then
      tupl;
  case (_,_,_)
    equation
        Debug.fcall(Flags.TEARING_DUMP, print, "getMaxFromListWithTuples failed!\n");
      then
        fail();        
  end matchcontinue;      
end getMaxFromListWithTuples;

protected function tearingVariable
"chooses the variable with maximum weight"
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input list<Integer> inLst;
  input list<Integer> inComp;
  input Real inMax;
  input Integer inVar;
  input list<Integer> inExclude;
  output tuple<Real,Integer> outTupl;
algorithm
  outTupl := matchcontinue(inM,inMT,inLst,inComp,inMax,inVar,inExclude)
  local
    BackendDAE.IncidenceMatrix m;
    BackendDAE.IncidenceMatrixT mt;
    list<Integer> rest,comp,exclude;
    Integer v,var;
    Real max;
    list<tuple<Real,Integer>> tupls;
    tuple<Real,Integer> tupl;
  case (m,mt,v::rest,comp,max,var,exclude)
    equation
      tupls = weightVariables(m,mt,v::rest,comp,{(0.0,0)},exclude);
      tupl = listGet(tupls,2);
      tupl = getMaxFromListWithTuples(tupls,(0.0,0),exclude);
    then
      tupl;
  case (_,_,_,_,_,_,_)
    equation
      Debug.fcall(Flags.TEARING_DUMP, print, "Select tearing variable failed!\n");
    then
      fail();        
  end matchcontinue;
end tearingVariable;

protected function printIntList
  input list<Integer> inLst;
  input String inStr;
  output String outStr;
algorithm
  outStr := matchcontinue(inLst,inStr)
  local
    list<Integer> rest;
    Integer v;
    String str,str1;
  case (v::rest,str)
    equation
       str1 = stringAppend(str,intString(v));
       str = printIntList(rest,str1);
     then
       str;
  case ({},str)
    equation
      str = stringAppend(str,"\n");
      Debug.fcall(Flags.TEARING_DUMP, print, str);
    then str;
  end matchcontinue;
end printIntList;

protected function weightVariables
  input BackendDAE.IncidenceMatrix inM; 
  input BackendDAE.IncidenceMatrixT inMT;
  input list<Integer> inVars;
  input list<Integer> inComp;
  input list<tuple<Real,Integer>> inTupls;
  input list<Integer> inExclude;
  output list<tuple<Real,Integer>> outTuple;  //(weight,variable)
algorithm
  outTuple := matchcontinue(inM,inMT,inVars,inComp,inTupls,inExclude)
  local
    BackendDAE.IncidenceMatrix m;
    BackendDAE.IncidenceMatrixT mt;
    list<Integer> rest,comp,exclude,incidenceLst;
    Integer v;
    Real weight1;
    tuple<Real,Integer> tupl2;
    list<tuple<Real,Integer>> tupls,tupls1;
  case (m,mt,{},comp,tupls,exclude)
    then
      tupls;
  case (m,mt,v::rest,comp,tupls,exclude)
    equation
      true = (v > 0);
      incidenceLst = mt[v];
      weight1 = weightVariables1(m,incidenceLst,exclude,0.0);
      tupl2 = (weight1,v);
      tupls1 = listAppend(tupls,{tupl2});
      tupls = weightVariables(m,mt,rest,comp,tupls1,exclude);
    then
      tupls;
  case (m,mt,v::rest,comp,tupls,exclude)
    equation
      false = (v > 0);
      tupls1 = weightVariables(m,mt,rest,comp,tupls,exclude);
    then
      tupls1;
  case (_,_,_,_,_,_)
    equation
      Debug.fcall(Flags.TEARING_DUMP, print, "weightVariables failed!\n");
    then
      fail();        
  end matchcontinue;
end weightVariables;


protected function weightVariables1 "helper function for weightVariables"
  input BackendDAE.IncidenceMatrix inM;
  input list<Integer> inIncidenceLst;
  input list<Integer> inExclude;
  input Real inWeight;
  output Real outWeight;
algorithm
  outWeight := matchcontinue(inM,inIncidenceLst,inExclude,inWeight)
  local
    BackendDAE.IncidenceMatrix m;
    list<Integer> rest,lst1,exclude;
    Integer eq,deg;
    Real weight,weight1,deg_real;
  case (m,{},exclude,weight) then weight;
  case (m,eq::rest,exclude,weight)
    equation
      true = (eq > 0);
      lst1 = m[eq];  //incident variables to equation v
      deg = listLength(lst1);  //edge degree
      deg_real = intReal(deg);
      weight = weight +. (1.0 /. deg_real);
      weight1 = weightVariables1(m,rest,exclude,weight);
     then
       weight1;
  case (m,eq::rest,exclude,weight)
    equation
      false = (eq > 0);
      weight1 = weightVariables1(m,rest,exclude,weight);
     then
       weight1;
  case (m,eq::rest,exclude,weight)
    equation
      weight1 = weightVariables1(m,rest,exclude,weight);
     then
       weight1;
  case (_,_,_,_)
    equation
      Debug.fcall(Flags.TEARING_DUMP, print, "weightVariables1 failed!\n");
    then
      fail();        
  end matchcontinue;
end weightVariables1;


protected function tearingSystem4
" function: tearingSystem4
  author: Frenkel TUD
  Internal Main loop for additional
  tearing vars and residual eqns."
  input BackendDAE.BackendDAE inDlow;
  input BackendDAE.BackendDAE inDlow1;
  input BackendDAE.IncidenceMatrix inM;
  input BackendDAE.IncidenceMatrixT inMT;
  input array<Integer> inV1;
  input array<Integer> inV2;
  input list<list<Integer>> inComps;
  input list<Integer> inResEqns;
  input list<Integer> inTearVars;
  input list<Integer> inTearEqns;
  input list<Integer> inComp;
  input Integer inCompCount;
  input list<DAE.ComponentRef> inCrlst;
  output list<Integer> outResEqns;
  output list<Integer> outTearVars;
  output list<Integer> outTearEqns;
  output BackendDAE.BackendDAE outDlow;
  output BackendDAE.BackendDAE outDlow1;
  output BackendDAE.IncidenceMatrix outM;
  output BackendDAE.IncidenceMatrixT outMT;
  output array<Integer> outV1;
  output array<Integer> outV2;
  output list<list<Integer>> outComp;
  output Integer outCompCount;
algorithm
  (outResEqns,outTearVars,outTearEqns,outDlow,outDlow1,outM,outMT,outV1,outV2,outComp,outCompCount):=
  matchcontinue (inDlow,inDlow1,inM,inMT,inV1,inV2,inComps,inResEqns,inTearVars,inTearEqns,inComp,inCompCount,inCrlst)
    local
      BackendDAE.BackendDAE dlow,dlow_1,dlow_2,dlow1,dlow1_1,dlow1_2;
      BackendDAE.IncidenceMatrix m,m_1,m_2;
      BackendDAE.IncidenceMatrixT mT,mT_1,mT_2;
      array<Integer> v1,v2,v1_1,v2_1,v1_2,v2_2;
      list<list<Integer>> comps,comps_1;
      list<Integer> tvars,comp,comp_1,tearingvars,residualeqns,ccomp,r,t,r_1,t_1,te,te_1,tearingeqns;
      Integer ll,compcount,compcount_1,compcount_2;
      list<Boolean> checklst;
      list<DAE.ComponentRef> crlst;
    case (dlow,dlow1,m,mT,v1,v2,{},r,t,te,ccomp,compcount,crlst)
      then
        (r,t,te,dlow,dlow1,m,mT,v1,v2,{},compcount);
    case (dlow,dlow1,m,mT,v1,v2,comp::comps,r,t,te,ccomp,compcount,crlst)
      equation
        // block ?
        ll = listLength(comp);
        true = ll > 1;
        // check block
        checklst = List.map1(comp,listMember,ccomp);
        true = listMember(true,checklst);
        // this is a block
        compcount_1 = compcount + 1;
        // get all interesting vars
        (tvars,_) = getTearingVars(m,v1,v2,comp,dlow);
        // try tearing
        (residualeqns,tearingvars,tearingeqns,dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comp_1) = tearingSystem2(dlow,dlow1,m,mT,v1,v2,comp,tvars,{},r,t,te,crlst);
        // next Block
        (r_1,t_1,te_1,dlow_2,dlow1_2,m_2,mT_2,v1_2,v2_2,comps_1,compcount_2) = tearingSystem4(dlow_1,dlow1_1,m_1,mT_1,v1_1,v2_1,comps,residualeqns,tearingvars,tearingeqns,ccomp,compcount_1,crlst);
      then
        (r_1,t_1,te_1,dlow_2,dlow1_2,m_2,mT_2,v1_2,v2_2,comp_1::comps_1,compcount_2);
    case (dlow,dlow1,m,mT,v1,v2,comp::comps,r,t,te,ccomp,compcount,crlst)
      equation
        // block ?
        ll = listLength(comp);
        true = ll > 1;
        // check block
        checklst = List.map1(comp,listMember,ccomp);
        true = listMember(true,checklst);
        // this is a block
        compcount_1 = compcount + 1;
        // next Block
        (r_1,t_1,tearingeqns,dlow_2,dlow1_1,m_2,mT_2,v1_2,v2_2,comps_1,compcount_2) = tearingSystem4(dlow,dlow1,m,mT,v1,v2,comps,r,t,te,ccomp,compcount_1,crlst);
      then
        (r_1,t_1,tearingeqns,dlow_2,dlow1_1,m_2,mT_2,v1_2,v2_2,comp::comps_1,compcount_2);
    case (dlow,dlow1,m,mT,v1,v2,comp::comps,r,t,te,ccomp,compcount,crlst)
      equation
        // next Block
        (r_1,t_1,te_1,dlow_2,dlow1_1,m_2,mT_2,v1_2,v2_2,comps_1,compcount_1) = tearingSystem4(dlow,dlow1,m,mT,v1,v2,comps,r,t,te,ccomp,compcount,crlst);
      then
        (r_1,t_1,te_1,dlow_2,dlow1_1,m_2,mT_2,v1_2,v2_2,comp::comps_1,compcount_1);
  end matchcontinue;
end tearingSystem4;

protected function getMaxfromListList
" function: getMaxfromArrayList
  helper for tearingSystem2 and tearingSystem3
  This function select the equation/variable
  with most connections to variables/equations.
  If more than once is there the first will
  be selected."
  input BackendDAE.IncidenceMatrixT inM;
  input list<Integer> inLst;
  input list<Integer> inComp;
  input Integer inMax;
  input Integer inEqn;
  input list<Integer> inExclude;
  output Integer outEqn;
  output Integer outMax;
algorithm
  (outEqn,outMax):=
  matchcontinue (inM,inLst,inComp,inMax,inEqn,inExclude)
    local
      BackendDAE.IncidenceMatrixT m;
      list<Integer> rest,eqn,eqn_1,eqn_2,eqn_3,comp,exclude;
      Integer v,v1,v2,max,max_1,en,en_1,en_2;
    case (m,{},comp,max,en,exclude) then (en,max);
    case (m,v::rest,comp,max,en,exclude)
      equation
        (en_1,max_1) = getMaxfromListList(m,rest,comp,max,en,exclude);
        true = v > 0;
        false = listMember(v,exclude);
        eqn = m[v];
        // remove negative
        eqn_1 = BackendDAEUtil.removeNegative(eqn);
        // select entries
        eqn_2 = List.select1(eqn_1,listMember,comp);
        // remove multiple entries
        eqn_3 = removeMultiple(eqn_2);
        v1 = listLength(eqn_3);
        v2 = intMax(v1,max_1);
        en_2 = Util.if_(v1>max_1,v,en_1);
      then
        (en_2,v2);
    case (m,v::rest,comp,max,en,exclude)
      equation
        (en_2,v2) = getMaxfromListList(m,rest,comp,max,en,exclude);
      then
        (en_2,v2);
  end matchcontinue;
end getMaxfromListList;

protected function getMaxfromListListVar
" function: getMaxfromArrayListVar
  same as getMaxfromListList but prefers states."
  input BackendDAE.IncidenceMatrixT inM;
  input list<Integer> inLst;
  input list<Integer> inComp;
  input Integer inMax;
  input Integer inEqn;
  input list<Integer> inExclude;
  input BackendDAE.Variables inVars;
  output Integer outEqn;
  output Integer outMax;
algorithm
  (outEqn,outMax):=
  matchcontinue (inM,inLst,inComp,inMax,inEqn,inExclude,inVars)
    local
      BackendDAE.IncidenceMatrixT m;
      list<Integer> rest,eqn,eqn_1,eqn_2,eqn_3,comp,exclude;
      Integer v,v1,v2,max,max_1,en,en_1,en_2;
      BackendDAE.Variables vars;
      BackendDAE.Var var;
      Boolean b;
      Integer si;
    case (m,{},comp,max,en,exclude,_) then (en,max);
    case (m,v::rest,comp,max,en,exclude,vars)
      equation
        (en_1,max_1) = getMaxfromListListVar(m,rest,comp,max,en,exclude,vars);
        true = v > 0;
        false = listMember(v,exclude);
        eqn = m[v];
        // remove negative
        eqn_1 = BackendDAEUtil.removeNegative(eqn);
        // select entries
        eqn_2 = List.select1(eqn_1,listMember,comp);
        // remove multiple entries
        eqn_3 = removeMultiple(eqn_2);
        // check if state or state der and prefer them
        var = BackendVariable.getVarAt(vars,v);
        b = BackendVariable.isStateorStateDerVar(var);
        si = Util.if_(b,listLength(comp),0);
        v1 = listLength(eqn_3)+si;
        v2 = intMax(v1,max_1);
        en_2 = Util.if_(v1>max_1,v,en_1);
      then
        (en_2,v2);
    case (m,v::rest,comp,max,en,exclude,vars)
      equation
        (en_2,v2) = getMaxfromListListVar(m,rest,comp,max,en,exclude,vars);
      then
        (en_2,v2);
  end matchcontinue;
end getMaxfromListListVar;

protected function removeMultiple
" function: removeMultiple
  remove mulitple entries from the list"
  input list<Integer> inLst;
  output list<Integer> outLst;
algorithm
  outLst:=
  matchcontinue (inLst)
    local
      list<Integer> rest,lst;
      Integer v;
    case ({}) then {};
    case (v::{})
      then
        {v};
    case (v::rest)
      equation
        false = listMember(v,rest);
        lst = removeMultiple(rest);
      then
        (v::lst);
    case (v::rest)
      equation
        true = listMember(v,rest);
        lst = removeMultiple(rest);
      then
        lst;
  end matchcontinue;
end removeMultiple;

protected function splitComps
" function: splitComps
  splits the comp in two list
  1: len(comp) == 1
  2: len(comp) > 1"
  input list<list<Integer>> inComps;
  output list<list<Integer>> outComps;
  output list<list<Integer>> outComps1;
algorithm
  (outComps,outComps1):=
  matchcontinue (inComps)
    local
      list<list<Integer>> rest,comps,comps1;
      list<Integer> comp;
      Integer v;
    case ({}) then ({},{});
    case ({v}::rest)
      equation
        (comps,comps1) = splitComps(rest);
      then
        (comps,{v}::comps1);
    case (comp::rest)
      equation
        (comps,comps1) = splitComps(rest);
      then
        (comp::comps,comps1);
  end matchcontinue;
end splitComps;

/* 
 * Generate sparse pattern
 */
 
 public function detectSparsePatternODE
  input BackendDAE.BackendDAE inBackendDAE;
  output BackendDAE.BackendDAE outBackendDAE;
protected
  BackendDAE.BackendDAE DAE; 
  BackendDAE.EqSystems eqs;
  BackendDAE.Shared shared;
  BackendDAE.SparseColoring coloredCols;
  BackendDAE.SparsePattern sparsePattern;
  list<BackendDAE.Var> states;
  BackendDAE.Var dummyVar;
  BackendDAE.Variables v;
algorithm
  
  BackendDAE.DAE(eqs = eqs) := inBackendDAE;
  // prepare a DAE
  DAE := BackendDAEUtil.copyBackendDAE(inBackendDAE);
  DAE := BackendDAEUtil.addDummyStateIfNeeded(DAE);
  DAE := collapseIndependentBlocks(DAE);
  DAE := BackendDAEUtil.transformBackendDAE(DAE, SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())), NONE(), SOME("dummyDerivative"));
  
  //get states for DAE
  BackendDAE.DAE(eqs = {BackendDAE.EQSYSTEM(orderedVars = v)}, shared=shared) := DAE;
  states := BackendVariable.getAllStateVarFromVariables(v);
  // generate sparse pattern
  (sparsePattern, coloredCols) := generateSparsePattern(DAE, states, states);

  shared := BackendDAEUtil.addBackendDAESharedJacobianSparsePattern(sparsePattern, coloredCols, BackendDAE.SymbolicJacobianAIndex, shared);

  outBackendDAE := BackendDAE.DAE(eqs,shared);
end detectSparsePatternODE;
 
public function generateSparsePattern
"
function: generateSparsePattern
  Function generated for a given set of variables and
  equations the sparsity pattern and a coloring of d jacobian matrix A^(NxM).
  col: N = size(diffVars)
  rows : M = size(diffedVars) 
  The sparsity pattern is represented basically as a list of lists, every list 
  represents the non-zero elements of a row.
  
  The coloring is saved as a list of lists, every list contains the
  cols with the same color. 
 
Author: wbraun
"
  input BackendDAE.BackendDAE inBackendDAE;
  input list<BackendDAE.Var> inDiffVars;    // "vars"
  input list<BackendDAE.Var> inDiffedVars;  // "eqns"
  output BackendDAE.SparsePattern outSparsePattern;
  output BackendDAE.SparseColoring outColoredCols;
algorithm
  (outSparsePattern,outColoredCols) := matchcontinue(inBackendDAE,inDiffVars,inDiffedVars)
    local
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst,syst1;
      BackendDAE.StrongComponents comps;
      BackendDAE.IncidenceMatrix adjMatrix,adjMatrixT;
      BackendDAE.Matching bdaeMatching;
      
      list<tuple<Integer, list<Integer>>>  sparseGraph, sparseGraphT;
      array<tuple<Integer, list<Integer>>> arraysparseGraph;
      
      Integer sizeN, sizeM, adjSize, adjSizeT;
      Integer nonZeroElements, sparseLength, maxdegree, maxColor;
      list<Integer> nodesList,nodesEqnsIndex;
      list<list<Integer>> sparsepattern,sparsepatternT, coloredlist;
      list<BackendDAE.Var> jacDiffVars, indiffVars, indiffedVars;
      BackendDAE.Variables diffedVars,varswithDiffs, v, origVars;
      BackendDAE.EquationArray orderedEqns;
      array<Option<list<Integer>>> forbiddenColor;
      array<Integer> colored, colored1, ass1, ass2;
      array<list<Integer>> coloredArray;
      list<Integer> alldegrees, varsIndexes;
      
      list<DAE.ComponentRef> diffCompRefs, diffedCompRefs;
      
      array<list<Integer>> eqnSparse,sparseArray,sparseArrayT;
      
      BackendDAE.SparseColoring coloring;
      list<list<DAE.ComponentRef>> translated;
      list<tuple<DAE.ComponentRef,list<DAE.ComponentRef>>> sparsetuple;
      
    case (_,{},_) then (({},({},{})),{});
    case (_,_,{}) then (({},({},{})),{});
    case(BackendDAE.DAE(eqs = (syst as BackendDAE.EQSYSTEM(matching=bdaeMatching as BackendDAE.MATCHING(comps=comps, ass1=ass1, ass2=ass2)))::{}, shared=shared),indiffVars,indiffedVars)
      equation
        Debug.fcall(Flags.JAC_DUMP,print," start getting sparsity pattern diff Vars : " +& intString(listLength(indiffedVars))  +& " diffed vars: " +& intString(listLength(indiffVars)) +&"\n");
        // prepare crefs   
        diffCompRefs = List.map(indiffVars, BackendVariable.varCref);
        diffedCompRefs = List.map(indiffedVars, BackendVariable.varCref);
        // create jacobian vars
        jacDiffVars =  List.map(indiffVars,BackendVariable.createpDerVar);
        sizeN = listLength(jacDiffVars);
        
        // generate adjacency matrix including diff vars        
        (syst1 as BackendDAE.EQSYSTEM(orderedVars=varswithDiffs,orderedEqs=orderedEqns)) = BackendDAEUtil.addVarsToEqSystem(syst,jacDiffVars);
        (adjMatrix, adjMatrixT) = BackendDAEUtil.incidenceMatrix(syst1,BackendDAE.SPARSE());
        adjSize = arrayLength(adjMatrix);
        adjSizeT = arrayLength(adjMatrixT);
        
        // Debug dumping
        /*
        Debug.fcall(Flags.JAC_DUMP2, BackendDump.dumpFullMatching, bdaeMatching);
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.printVarList,BackendVariable.varList(varswithDiffs));
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.printEquationList,BackendEquation.equationList(orderedEqns));
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpIncidenceMatrix,adjMatrix);
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpIncidenceMatrixT,adjMatrixT);
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpComponents, comps);
        */
        
        // get indexes of diffed vars (rows)
        diffedVars = BackendVariable.listVar1(indiffedVars);  
        nodesEqnsIndex = BackendVariable.getVarIndexFromVariables(diffedVars,varswithDiffs);
        nodesEqnsIndex = List.map1(nodesEqnsIndex, Util.arrayGetIndexFirst, ass1);
        sizeM = listLength(nodesEqnsIndex);
        
        Debug.fcall(Flags.JAC_DUMP2, print, "nodesEqnsIndexs: ");
        Debug.fcall(Flags.JAC_DUMP2, BackendDump.dumpIncidenceRow, nodesEqnsIndex);
        Debug.fcall(Flags.JAC_DUMP2, print, "\n");
        
        
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> build sparse graph: " +& realString(clock()) +& "\n");
        // prepare dependency matrix by fill 
        eqnSparse = arrayCreate(adjSize,{});
        eqnSparse = prepareSparsePatternT(eqnSparse, adjSizeT-(sizeN-1), adjSizeT, adjMatrixT);
        sparsepattern = arrayList(eqnSparse);
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpSparsePattern,sparsepattern);
        
        Debug.fcall(Flags.JAC_DUMP,print, "analytical Jacobians[SPARSE] -> prepared arrayList for transpose list: " +& realString(clock()) +& "\n");
        eqnSparse = getSparsePattern(comps, eqnSparse, adjMatrix, adjMatrixT);
        eqnSparse = getSparsePattern(comps, eqnSparse, adjMatrix, adjMatrixT);
        sparsepattern = arrayList(eqnSparse);
        nonZeroElements = List.lengthListElements(sparsepattern);
        (alldegrees, maxdegree) = List.mapFold(sparsepattern, findDegrees, 1);        
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> got sparse pattern nonZeroElements: "+& intString(nonZeroElements) +& " maxNodeDegree: " +& intString(maxdegree) +& " time : " +& realString(clock()) +& "\n");
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpSparsePattern,sparsepattern);
        sparseArray = Util.arraySelect(eqnSparse, nodesEqnsIndex);
        sparsepattern = arrayList(sparseArray);
        sparsepattern = List.map1List(sparsepattern, intSub, adjSizeT-sizeN);
        sparseArray = listArray(sparsepattern);
        
        // transpose the column-based pattern to row-based pattern
        //sparseLength = Util.if_(sizeM > sizeN, sizeM, sizeN);
        sparseArrayT = arrayCreate(sizeN,{});
        sparseArrayT = transposeSparsePattern(sparsepattern, sparseArrayT, 1);
        sparsepatternT = arrayList(sparseArrayT);
        //sparsepatternT = List.firstN(sparsepatternT, listLength(diffCompRefs));
        
        (alldegrees, maxdegree) = List.mapFold(sparsepatternT, findDegrees, 1);
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> got sparse pattern nonZeroElements: "+& intString(nonZeroElements) +& " maxNodeDegree: " +& intString(maxdegree) +& " time : " +& realString(clock()) +& "\n");
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpSparsePattern,sparsepattern);
        Debug.fcall(Flags.JAC_DUMP2,BackendDump.dumpSparsePattern,sparsepatternT);

        translated = List.mapList1_1(sparsepatternT, List.getIndexFirst, diffedCompRefs);
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> translated to DAE.ComRefs\n");
        sparsetuple = List.threadTuple(diffCompRefs, translated);
        
        
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> build sparse  graph.\n");
        // build up a graph of pattern
        nodesList = List.intRange2(1,adjSize);
        sparseGraph = Graph.buildGraph(nodesList,createBipartiteGraph,sparseArray);
        sparseGraphT = Graph.buildGraph(List.intRange2(1,sizeN),createBipartiteGraph,sparseArrayT);
        Debug.fcall(Flags.JAC_DUMP2,print,"sparse graph: \n");
        Debug.fcall(Flags.JAC_DUMP2,Graph.printGraphInt,sparseGraph);
        Debug.fcall(Flags.JAC_DUMP2,print,"transposed sparse graph: \n");
        Debug.fcall(Flags.JAC_DUMP2,Graph.printGraphInt,sparseGraphT);
        
        Debug.fcall(Flags.JAC_DUMP,print,"analytical Jacobians[SPARSE] -> builded graph for coloring.\n");
        // color sparse bipartite graph
        forbiddenColor = arrayCreate(sizeN,NONE());
        colored = arrayCreate(sizeN,0);
        arraysparseGraph = listArray(sparseGraph);
        colored1 = Graph.partialDistance2colorInt(sparseGraphT, forbiddenColor, nodesList, arraysparseGraph, colored);
        // get max color used
        maxColor = Util.arrayFold(colored1, intMax, 0);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians[SPARSE] -> colored graph with " +& intString(maxColor) +& " colors. Time : " +& realString(clock()) +& "\n");

        // map index of that array into colors
        coloredArray = arrayCreate(maxColor, {});
        coloredlist = arrayList(mapIndexColors(colored1, listLength(diffCompRefs), coloredArray));
        
        Debug.fcall(Flags.JAC_DUMP2, print, "Print Coloring Cols: \n");
        Debug.fcall(Flags.JAC_DUMP2, BackendDump.dumpSparsePattern, coloredlist);
        
        coloring = List.mapList1_1(coloredlist, List.getIndexFirst, diffCompRefs);
        
        //without coloring
        //coloring = List.transposeList({diffCompRefs});
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians[SPARSE] -> ready! " +& realString(clock()) +& "\n");
      then ((sparsetuple, (diffCompRefs, diffedCompRefs)), coloring);
        else
      equation
        Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.generateSparsePattern failed"});
      then fail();
  end matchcontinue;
end generateSparsePattern;

protected function mapIndexColors
  input array<Integer> inColors;
  input Integer inMaxIndex;
  input array<list<Integer>> inArray;
  output array<list<Integer>> outColors;
algorithm
  outColors := matchcontinue(inColors, inMaxIndex, inArray)
    local
      Integer i, index;
      list<Integer> lst;
    case (_, 0, _) then inArray;
    case (_, i, _)
      equation
        index = arrayGet(inColors, i);
        lst = arrayGet(inArray, index);
        lst = listAppend({i},lst);
        _ = arrayUpdate(inArray, index, lst);
      then
        mapIndexColors(inColors, i-1, inArray);
/*    case (_, i, _)
      equation
        print("i " +& intString(i) +& "\n");
        print("inColors " +& intString(arrayLength(inColors)) +& "\n");
        index = arrayGet(inColors, i);
        print("index " +& intString(index) +& "\n");
        print("inArray " +& intString(arrayLength(inArray)) +& "\n");
      then
        fail();
*/    else
      equation
        Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.generateSparsePattern: mapIndexColors failed"});
      then
         fail();
 end matchcontinue;
end mapIndexColors;

protected function createDirectedGraph
  input Integer inNode;
  input tuple<BackendDAE.IncidenceMatrix,BackendDAE.Matching> intupleArgs;
  output list<Integer> outEdges; 
algorithm
  outEdges := matchcontinue(inNode,intupleArgs)
  local
    BackendDAE.IncidenceMatrix incidenceMat;
    BackendDAE.IncidenceMatrixElement oneElement;
    array<Integer> ass1,ass2;
    Integer assignment;
    list<Integer> outEdges;
    list<String> oneEleStr;
    case(inNode, (incidenceMat,BackendDAE.MATCHING(ass1 = ass1)))
      equation
        //Debug.fcall(Flags.JAC_DUMP2, print,"In Node : " +& intString(inNode) +& " ");
        assignment = arrayGet(ass1,inNode);
        oneElement = arrayGet(incidenceMat,assignment);
        //Debug.fcall(Flags.JAC_DUMP2, print,"assignt to : " +& intString(assignment) +& "\n");
        //Debug.fcall(Flags.JAC_DUMP2, print,"elements on node : ");
        //Debug.fcall(Flags.JAC_DUMP2, BackendDump.dumpIncidenceRow,oneElement);
        ( outEdges,_) = List.deleteMemberOnTrue(inNode,oneElement,intEq);
    then outEdges;
    case(inNode, (_,_))
      then {};        
  end matchcontinue;
end createDirectedGraph;

protected function createBipartiteGraph
  input Integer inNode;
  input array<list<Integer>> inSparsePattern;
  output list<Integer> outEdges; 
algorithm
  outEdges := matchcontinue(inNode,inSparsePattern)
    case(_, _)
      equation
        outEdges = arrayGet(inSparsePattern,inNode);
    then outEdges;
    case(_, _)
      then {};        
  end matchcontinue;
end createBipartiteGraph;

protected function getSparsePatternGraph
  input list<Integer> inNodes1; //nodesEqnsIndex
  input Integer inMaxGraphIndex; //nodesVarsIndex
  input Integer inMaxNodeIndex; //nodesVarsIndex
  input array<tuple<Integer, list<Integer>>> inGraph;
  output list<list<Integer>> outSparsePattern;
algorithm 
  outSparsePattern :=match(inNodes1,inMaxGraphIndex,inMaxNodeIndex,inGraph)
  local
    list<Integer> rest;
    Integer node;
    list<Integer> reachableNodes;
    list<list<Integer>> result;
    case(node::{},inMaxGraphIndex,inMaxNodeIndex,inGraph)
      equation
        reachableNodes = Graph.allReachableNodesInt(({node},{}), inGraph, inMaxGraphIndex, inMaxNodeIndex);
        reachableNodes = List.select1(reachableNodes, intGe, inMaxGraphIndex);
      then {reachableNodes};        
    case(node::rest,inMaxGraphIndex,inMaxNodeIndex,inGraph)
      equation
        reachableNodes = Graph.allReachableNodesInt(({node},{}), inGraph, inMaxGraphIndex, inMaxNodeIndex);
        reachableNodes = List.select1(reachableNodes, intGe, inMaxGraphIndex);
        result = getSparsePatternGraph(rest,inMaxGraphIndex,inMaxNodeIndex,inGraph);
        result = listAppend({reachableNodes},result);
      then result;      
    else
       equation
       print("BackendDAEOptimize.getSparsePattern failed\n");
       Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.getSparsePattern failed"});
       then fail();
  end match;
end getSparsePatternGraph;

protected function prepareSparsePatternT 
  input array<list<Integer>> inSparseT;
  input Integer inStartNode;
  input Integer inEndNode;
  input BackendDAE.IncidenceMatrix inMatrixT;
  output array<list<Integer>> outSparseT;
algorithm
  outSparseT := matchcontinue(inSparseT,inStartNode,inEndNode,inMatrixT)
  local
    list<Integer> rowElements;
    case (_,_,_,_)
      equation
        true = (inStartNode <= inEndNode);
        rowElements = arrayGet(inMatrixT,inStartNode);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, {inStartNode}, inSparseT);
        outSparseT = prepareSparsePatternT(inSparseT, inStartNode+1, inEndNode, inMatrixT);
      then outSparseT;     
    case (_,_,_,_) then inSparseT;
  end matchcontinue;
end prepareSparsePatternT;

protected function getSparsePattern
  input BackendDAE.StrongComponents inComponents;
  input array<list<Integer>> inResults; //
  input BackendDAE.IncidenceMatrix inMatrix;
  input BackendDAE.IncidenceMatrix inMatrixT;
  output array<list<Integer>> outSparsePattern;
algorithm 
  outSparsePattern :=matchcontinue(inComponents,inResults,inMatrix,inMatrixT)
  local
    list<Integer> vars, vars1,eqns, eqns1, eqnlst, rowElements;
    Integer var, eqn;
    array<list<Integer>> result;
    BackendDAE.StrongComponents rest;
    list<list<Integer>>  rowElementsList, eqnlstList;
    BackendDAE.StrongComponent condSystem;
    list<tuple<Integer, list<Integer>>> otherEqnVarTpl;
    list<list<Integer>> varsElements, dumpList;
    case ({},result,_,_) then result;
    case(BackendDAE.SINGLEEQUATION(eqn=eqn,var=var)::rest,result,_,_)
      equation
        //print("SINGLEEQUATION update: ");
        // get incedece row for curent equation set
        //print("find for dependecies for  eqn:" +& intString(eqn) +& " \n");
        rowElements = arrayGet(inMatrixT, var);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.EQUATIONSYSTEM(eqns=eqns,vars=vars)::rest,result,_,_)
      equation
        //print("EQUATIONSYSTEM update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        
        eqnlstList = List.map1(eqns, Util.arrayGetIndexFirst, result);
        eqnlst = List.unionList(eqnlstList);
        List.map2_0(eqns, Util.arrayUpdateElementListUnion, eqnlst, result);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=BackendDAE.EQUATIONSYSTEM(eqns=eqns1,vars=vars1), disc_eqns=eqns,disc_vars=vars)::rest,result,_,_)
      equation
        //print("MIXEDEQUATIONSYSTEM update: ");
        vars= listAppend(vars,vars1);
        eqns= listAppend(eqns,eqns1);
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlstList = List.map1(eqns, Util.arrayGetIndexFirst, result);
        eqnlst = List.unionList(eqnlstList);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.SINGLEARRAY(eqn=eqn,vars=vars)::rest,result,_,_)
      equation
        //print("SINGLEARRAY update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.SINGLEIFEQUATION(eqn=eqn,vars=vars)::rest,result,_,_)
      equation
        //print("SINGLEARRAY update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.SINGLEALGORITHM(eqn=eqn,vars=vars)::rest,result,_,_)
      equation
        //print("SINGLEALGORITHM update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    case(BackendDAE.SINGLECOMPLEXEQUATION(eqn=eqn,vars=vars)::rest,result,_,_)
      equation
        //print("SINGLECOMPLEXEQUATION update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);  
      then result;
    case(BackendDAE.SINGLEWHENEQUATION(eqn=eqn,vars=vars)::rest,result,_,_)
      equation
        //print("SINGLEWHENEQUATION update: ");
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        eqnlst = arrayGet(result, eqn);
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n"); 
        */        
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);  
      then result;
    case(BackendDAE.TORNSYSTEM(residualequations=eqns,tearingvars=vars,otherEqnVarTpl=otherEqnVarTpl)::rest,result,_,_)
      equation
        //print("TORNSYSTEM tearing update: ");
        //processed tearing eqns and vars
        rowElementsList = List.map1(vars, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = List.unionList(rowElementsList);
        
        eqns1 = List.map(otherEqnVarTpl,Util.tuple21);
        varsElements = List.map(otherEqnVarTpl,Util.tuple22);
        
        vars1 = List.unionList(varsElements);
        rowElementsList = List.map1(vars1, Util.arrayGetIndexFirst, inMatrixT);
        rowElements = listAppend(rowElements,List.unionList(rowElementsList));
        
        eqns1 = listAppend(eqns,eqns1);
        eqnlstList = List.map1(eqns1, Util.arrayGetIndexFirst, result);
        eqnlst = List.unionList(eqnlstList);
        
        List.map2_0(rowElements, Util.arrayUpdateElementListUnion, eqnlst, result);
        /*
        BackendDump.dumpIncidenceRow(rowElements);
        dumpList = List.map1(rowElements, Util.arrayGetIndexFirst, result);
        List.map_0(dumpList, BackendDump.dumpIncidenceRow);
        print("\n\n");
        */
        result = getSparsePattern(rest,result,inMatrix,inMatrixT);
      then result;
    else
       equation
       Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.getSparsePatternNew failed"});
       then fail();
  end matchcontinue;
end getSparsePattern;

public function findDegrees
  input list<ElementType> inList;
  input Integer inValue;
  output Integer outDegree;
  output Integer outMaxDegree;
replaceable type ElementType subtypeof Any;  
algorithm
  outDegree := listLength(inList);
  outMaxDegree := intMax(inValue,outDegree);
end findDegrees;

protected function transposeSparsePattern
  input list<list<Integer>> inSparsePattern; 
  input array<list<Integer>> inAccumList;
  input Integer inValue;
  output array<list<Integer>> outSparsePattern;
algorithm
  outSparsePattern := match(inSparsePattern, inAccumList, inValue)
  local 
    list<Integer> oneElem;
    list<list<Integer>> rest;
    array<list<Integer>>  accumList;
    case ({},_,_) then inAccumList;
    case (oneElem::rest, _, _)
      equation
        accumList = transposeSparsePattern2(oneElem, inAccumList, inValue);
       then transposeSparsePattern(rest, accumList, inValue+1); 
  end match;
end transposeSparsePattern;

protected function transposeSparsePattern2
  input list<Integer> inSparsePatternElem; 
  input array<list<Integer>> inAccumList;
  input Integer inValue;
  output array<list<Integer>> outSparsePattern;
algorithm
  outSparsePattern := match(inSparsePatternElem, inAccumList, inValue)
  local 
    Integer oneElem;
    list<Integer> rest, tmplist;
    array<list<Integer>>  accumList;
    case ({},_,_) then inAccumList;
    case (oneElem::rest,_, _)
      equation
        tmplist = arrayGet(inAccumList,oneElem);
        tmplist = listAppend(tmplist,{inValue});
        accumList = arrayUpdate(inAccumList, oneElem, tmplist);
       then transposeSparsePattern2(rest, accumList, inValue); 
  end match;
end transposeSparsePattern2;




/* 
 * initialization stuff
 *
 */
public function collectInitialEquations "function collectInitialEquations
  author: lochel
  This function collects all initial equations in the following order:
    - initial equations
    - implicit initial equations
    - initial algorithms"
  input BackendDAE.BackendDAE inDAE;
  output list<BackendDAE.Equation> outEquations;
  output Integer outNumberOfInitialEquations;
  output Integer outNumberOfInitialAlgorithms;
algorithm
  (outEquations, outNumberOfInitialEquations, outNumberOfInitialAlgorithms) := matchcontinue(inDAE)
    local
      BackendDAE.EqSystems eqs;
      BackendDAE.EquationArray initialEqs;
      
      Integer numberOfInitialEquations, numberOfInitialAlgorithms;
      list<BackendDAE.Equation> initialEqs_lst, initialEqs_lst1, initialEqs_lst2, initialEqs_lst3;
    
    case (BackendDAE.DAE(eqs=eqs, shared=BackendDAE.SHARED(initialEqs=initialEqs))) equation
      // [initial equations]
      // initial_equation
      initialEqs_lst = BackendEquation.equationList(initialEqs);
      initialEqs_lst1 = List.select(initialEqs_lst, BackendEquation.isNotAlgorithm);
      
      // [orderedVars] with fixed=true
      // 0 = v - start(v); fixed(v) = true
      initialEqs_lst2 = generateImplicitInitialEquations(List.flatten(List.mapMap(eqs, BackendVariable.daeVars, BackendVariable.varList)));
      
      // [initial algorithms]
      // remove algorithms, I have no clue what the reason is but is was done before also
      initialEqs_lst3 = List.select(initialEqs_lst, BackendEquation.isAlgorithm);
      //initialEqs_lst3 = {};
      
      // append and count
      initialEqs_lst = listAppend(initialEqs_lst1, initialEqs_lst2);
      numberOfInitialEquations = BackendEquation.equationLstSize(initialEqs_lst);
      initialEqs_lst = listAppend(initialEqs_lst, initialEqs_lst3);
      numberOfInitialAlgorithms = BackendEquation.equationLstSize(initialEqs_lst3);
    then (initialEqs_lst, numberOfInitialEquations, numberOfInitialAlgorithms);
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function collectInitialEquations failed"});
    then fail();
  end matchcontinue;
end collectInitialEquations;

public function generateImplicitInitialEquations "function generateImplicitInitialEquations
  author: lochel
  Helper for collectInitialEquations.
  This function generates implicit initial equations for fixed variables."
  input list<BackendDAE.Var> inVars;
  output list<BackendDAE.Equation> outEqns;
algorithm
  outEqns := matchcontinue(inVars)
  local
    BackendDAE.Var var;
    list<BackendDAE.Var> vars;
    BackendDAE.Equation eqn;
    list<BackendDAE.Equation> eqns;
    DAE.Exp e, e1, crefExp, startExp;
    DAE.ComponentRef cref;
    DAE.Type tp;
    
    case({}) then {};
      
    case(var::vars) equation
      true = BackendVariable.varFixed(var);
      false = BackendVariable.isStateVar(var);
      false = BackendVariable.isParam(var);
      false = BackendVariable.isVarDiscrete(var);
      
      cref = BackendVariable.varCref(var);
      crefExp = DAE.CREF(cref, DAE.T_REAL_DEFAULT);
      
      e = Expression.crefExp(cref);
      tp = Expression.typeof(e);
      startExp = Expression.makeBuiltinCall("$_start", {e}, tp);
      e1 = DAE.BINARY(crefExp, DAE.SUB(DAE.T_REAL_DEFAULT), startExp);
      
      eqn = BackendDAE.RESIDUAL_EQUATION(e1, DAE.emptyElementSource,false);
      eqns = generateImplicitInitialEquations(vars);
    then eqn::eqns;
      
    case(var::vars) equation
      eqns = generateImplicitInitialEquations(vars);
    then eqns;
      
    case(_) equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateImplicitInitialEquations failed"});
    then fail();
  end matchcontinue;
end generateImplicitInitialEquations;

public function convertInitialResidualsIntoInitialEquations "function convertInitialResidualsIntoInitialEquations
  author: lochel
  This function converts initial residuals into initial equations of the following form:
    e.g.: 0 = a+b -> $res1 = a+b"
  input list<BackendDAE.Equation> inResidualList;
  output list<BackendDAE.Equation> outEquationList;
  output list<BackendDAE.Var> outVariableList;
algorithm
  (outEquationList, outVariableList) := convertInitialResidualsIntoInitialEquations2(inResidualList, 1, {}, {});
end convertInitialResidualsIntoInitialEquations;

protected function convertInitialResidualsIntoInitialEquations2 "function generateInitialResidualEquations2
  author: lochel
  This is a helper function of convertInitialResidualsIntoInitialEquations."
  input list<BackendDAE.Equation> inEquationList;
  input Integer inIndex;
  input list<BackendDAE.Equation> iEquationList;
  input list<BackendDAE.Var> iVariableList;
  output list<BackendDAE.Equation> outEquationList;
  output list<BackendDAE.Var> outVariableList;
algorithm
  (outEquationList, outVariableList) := matchcontinue(inEquationList, inIndex, iEquationList, iVariableList)
    local
      Integer index;
      list<BackendDAE.Equation> restEquationList;
      list<BackendDAE.Equation> equationList;
      list<BackendDAE.Var> variableList;
      
      DAE.Exp expVarName;
      DAE.Exp exp;
      DAE.ElementSource source "origin of equation";
      
      String varName, errorMessage;
      DAE.ComponentRef componentRef;
      BackendDAE.Equation currEquation;
      BackendDAE.Var currVariable;
    
    case({}, _, _ , _)
    then (listReverse(iEquationList), listReverse(iVariableList));
    
    case((BackendDAE.RESIDUAL_EQUATION(exp=exp,source=source))::restEquationList, index,_,_) equation
      varName = "$res" +& intString(index);
      componentRef = DAE.CREF_IDENT(varName, DAE.T_REAL_DEFAULT, {});
      expVarName = DAE.CREF(componentRef, DAE.T_REAL_DEFAULT);
      currEquation = BackendDAE.EQUATION(expVarName, exp, source, false);
      
      currVariable = BackendDAE.VAR(componentRef, BackendDAE.VARIABLE(), DAE.OUTPUT(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());

      (equationList, variableList) = convertInitialResidualsIntoInitialEquations2(restEquationList, index+1,currEquation::iEquationList,currVariable::iVariableList);
    then (equationList, variableList);
    
    case(currEquation::_, _,_,_) equation
      errorMessage = "./Compiler/BackEnd/BackendDAEOptimize.mo: function convertInitialResidualsIntoInitialEquations2 failed: " +& BackendDump.equationString(currEquation);
      Error.addMessage(Error.INTERNAL_ERROR, {errorMessage});
    then fail();
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function convertInitialResidualsIntoInitialEquations2 failed"});
    then fail();
  end matchcontinue;
end convertInitialResidualsIntoInitialEquations2;

protected function redirectOutputToBiDir "function redirectOutputToBiDir
  author: lochel
  This is a helper function of generateInitialMatrices."
  input list<BackendDAE.Var> inVariableList;
  output list<BackendDAE.Var> outVariableList;
algorithm
  outVariableList := matchcontinue(inVariableList)
    local
      list<BackendDAE.Var> variableList;
      BackendDAE.Var variable;
      
      list<BackendDAE.Var> resVariableList;
      BackendDAE.Var resVariable;
    
    case ({})
    then ({});
    
    case (variable::variableList) equation
      true = BackendVariable.isOutputVar(variable);
      //true = BackendVariable.isVarOnTopLevelAndOutput(variable);
      resVariable = BackendVariable.setVarDirection(variable, DAE.BIDIR());
      resVariableList = redirectOutputToBiDir(variableList);
    then (resVariable::resVariableList);
      
    case (variable::variableList) equation
      resVariableList = redirectOutputToBiDir(variableList);
    then (variable::resVariableList);
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function redirectOutputToBiDir failed"});
    then fail();
  end matchcontinue;
end redirectOutputToBiDir;

public function generateInitialMatrices "function generateInitialMatrices
  author: lochel
  This function generates symbolic matrices for initialization."
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.SymbolicJacobian outJacG;
  output BackendDAE.SparsePattern outSparsityPattern;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outJacG, outSparsityPattern, outDAE) := matchcontinue(inDAE)
    local
      BackendDAE.BackendDAE DAE;
      
      list<BackendDAE.Equation> initialEqs_lst, initialEquationList;
      list<BackendDAE.Var>  initialVariableList;
      BackendDAE.Variables initialVars;
      BackendDAE.EquationArray initialEqs;
      BackendDAE.EqSystem initEqSystem;
      BackendDAE.SymbolicJacobian jacobian;
      
      BackendDAE.Variables orderedVars, knownVars;
      BackendDAE.EquationArray orderedEqs;
      
      list<BackendDAE.Var>  orderedVarList, knownVarList, states, inputs, outputs, parameters;
      list<DAE.ComponentRef> orderedVarCrefList, knownVarCrefList;
      BackendDAE.SparsePattern sparsityPattern;
      
      BackendDAE.Shared shared;
    
    case(DAE) equation
      (initialEqs_lst, _, _) = collectInitialEquations(DAE);
      
      //BackendDump.dumpBackendDAEEqnList(initialEqs_lst, "initial residuals 1", false);
      initialEqs_lst = BackendEquation.traverseBackendDAEEqns(BackendEquation.listEquation(initialEqs_lst), BackendDAEUtil.traverseEquationToScalarResidualForm, {});  // ugly
      //BackendDump.dumpBackendDAEEqnList(initialEqs_lst, "initial residuals 2", false);
      
      (initialEquationList, initialVariableList) = convertInitialResidualsIntoInitialEquations(initialEqs_lst);
      initialEqs = BackendEquation.listEquation(initialEquationList);
      initialVars = BackendVariable.listVar1(initialVariableList);
      //BackendDump.dumpBackendDAEEqnList(initialEquationList, "initial equations", false);
      //BackendDump.dumpBackendDAEVarList(initialVariableList, "initial vars");
      
      initEqSystem = BackendDAE.EQSYSTEM(initialVars, initialEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{});
      
      // redirect output to bidir
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays
      DAE = collapseIndependentBlocks(DAE);
      BackendDAE.DAE(eqs={BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, shared=shared) = DAE;
      orderedVarList = BackendVariable.varList(orderedVars);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 1");
      orderedVarList = redirectOutputToBiDir(orderedVarList);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 2");
      orderedVars = BackendVariable.listVar1(orderedVarList);
      
      // add initial equations and $res-variables
      DAE = BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars, orderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{}), initEqSystem}, shared);
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays
      
      DAE = collapseIndependentBlocks(DAE);                             // merge everything together
      DAE = BackendDAEUtil.transformBackendDAE(DAE, SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())), NONE(), SOME("dummyDerivative"));  // calculate matching
      
      // preparing all needed variables
      BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, BackendDAE.SHARED(knownVars=knownVars)) = DAE;

      orderedVarList = BackendVariable.varList(orderedVars);
      orderedVarCrefList = List.map(orderedVarList, BackendVariable.varCref);
      knownVarList = BackendVariable.varList(knownVars);
      knownVarCrefList = List.map(knownVarList, BackendVariable.varCref);
      states = BackendVariable.getAllStateVarFromVariables(orderedVars);
      inputs = List.select(knownVarList, BackendVariable.isInput);
      parameters = List.select(knownVarList, BackendVariable.isParam);
      outputs = List.select(orderedVarList, BackendVariable.isVarOnTopLevelAndOutput);
      
      (jacobian, sparsityPattern, _) = createJacobian(DAE,                                     // DAE
                                                      states,                                  // 
                                                      BackendVariable.listVar1(states),         // 
                                                      BackendVariable.listVar1(inputs),         // 
                                                      BackendVariable.listVar1(parameters),     // 
                                                      BackendVariable.listVar1(outputs),        // 
                                                      orderedVarList,                          // 
                                                      "G");                                    // name
    then (jacobian, sparsityPattern, DAE);
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateInitialMatrices failed"});
    then fail();
  end matchcontinue;
end generateInitialMatrices;

public function generateInitialMatricesDAE "function generateInitialMatricesDAE
  author: lochel
  This function generates a DAE for the symbolic matrices for initialization."
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
  output list<BackendDAE.Var> outVars;  // "initial equation"
algorithm
  (outDAE, outVars) := matchcontinue(inDAE)
    local
      BackendDAE.BackendDAE DAE;
      
      list<BackendDAE.Equation> initialEqs_lst, initialEquationList;
      list<BackendDAE.Var>  initialVariableList;
      BackendDAE.Variables initialVars;
      BackendDAE.EquationArray initialEqs;
      BackendDAE.EqSystem initEqSystem;
      BackendDAE.SymbolicJacobian jacobian;
      
      BackendDAE.Variables orderedVars, knownVars;
      BackendDAE.EquationArray orderedEqs;
      
      list<BackendDAE.Var>  orderedVarList, knownVarList, states, inputs, outputs, parameters;
      list<DAE.ComponentRef> orderedVarCrefList, knownVarCrefList;
      BackendDAE.SparsePattern sparsityPattern;
      
      BackendDAE.Shared shared;
    
    case(DAE) equation
      (initialEqs_lst, _, _) = collectInitialEquations(DAE);
      
      //BackendDump.dumpBackendDAEEqnList(initialEqs_lst, "initial residuals 1", false);
      initialEqs_lst = BackendEquation.traverseBackendDAEEqns(BackendEquation.listEquation(initialEqs_lst), BackendDAEUtil.traverseEquationToScalarResidualForm, {});  // ugly
      //BackendDump.dumpBackendDAEEqnList(initialEqs_lst, "initial residuals 2", false);
      
      (initialEquationList, initialVariableList) = convertInitialResidualsIntoInitialEquations(initialEqs_lst);
      initialEqs = BackendEquation.listEquation(initialEquationList);
      initialVars = BackendVariable.listVar1(initialVariableList);
      //BackendDump.dumpBackendDAEEqnList(initialEquationList, "initial equations", false);
      //BackendDump.dumpBackendDAEVarList(initialVariableList, "initial vars");
      
      initEqSystem = BackendDAE.EQSYSTEM(initialVars, initialEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{});
      
      // redirect output to bidir
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays
      DAE = collapseIndependentBlocks(DAE);
      BackendDAE.DAE(eqs={BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, shared=shared) = DAE;
      orderedVarList = BackendVariable.varList(orderedVars);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 1");
      orderedVarList = redirectOutputToBiDir(orderedVarList);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 2");
      orderedVars = BackendVariable.listVar1(orderedVarList);
      
      // add initial equations and $res-variables
      DAE = BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars, orderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{}), initEqSystem}, shared);
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays

      DAE = collapseIndependentBlocks(DAE);                             // merge everything together
      DAE = BackendDAEUtil.transformBackendDAE(DAE, SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())), NONE(), SOME("dummyDerivative"));  // calculate matching
      
      // preparing all needed variables
      BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, BackendDAE.SHARED(knownVars=knownVars)) = DAE;

      orderedVarList = BackendVariable.varList(orderedVars);
      orderedVarCrefList = List.map(orderedVarList, BackendVariable.varCref);
      knownVarList = BackendVariable.varList(knownVars);
      knownVarCrefList = List.map(knownVarList, BackendVariable.varCref);
      states = BackendVariable.getAllStateVarFromVariables(orderedVars);
      inputs = List.select(knownVarList, BackendVariable.isInput);
      parameters = List.select(knownVarList, BackendVariable.isParam);
      outputs = List.select(orderedVarList, BackendVariable.isVarOnTopLevelAndOutput);
    then (DAE, outputs);
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateInitialMatricesDAE failed"});
    then fail();
  end matchcontinue;
end generateInitialMatricesDAE;

public function generateInitialMatricesSparsityPattern "function generateInitialMatricesSparsityPattern
  author: lochel
  This function generates symbolic matrices for initialization."
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.SparsePattern outSparsityPattern;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outSparsityPattern, outDAE) := matchcontinue(inDAE)
    local
      BackendDAE.BackendDAE DAE;
      
      list<BackendDAE.Equation> initialEqs_lst, initialEquationList;
      list<BackendDAE.Var>  initialVariableList;
      BackendDAE.Variables initialVars;
      BackendDAE.EquationArray initialEqs;
      BackendDAE.EqSystem initEqSystem;
      BackendDAE.SymbolicJacobian jacobian;
      
      BackendDAE.Variables orderedVars, knownVars;
      BackendDAE.EquationArray orderedEqs;
      
      list<BackendDAE.Var>  orderedVarList, knownVarList, states, inputs, outputs, parameters;
      list<DAE.ComponentRef> orderedVarCrefList, knownVarCrefList;
      BackendDAE.SparsePattern sparsityPattern;
      
      BackendDAE.Shared shared;
    
    case(DAE) equation
      (initialEqs_lst, _, _) = collectInitialEquations(DAE);
      initialEqs_lst = BackendEquation.traverseBackendDAEEqns(BackendEquation.listEquation(initialEqs_lst), BackendDAEUtil.traverseEquationToScalarResidualForm, {});  // ugly
      
      //BackendDump.dumpBackendDAEEqnList(initialEqs_lst, "initial residuals", false);
      (initialEquationList, initialVariableList) = convertInitialResidualsIntoInitialEquations(initialEqs_lst);
      initialEqs = BackendEquation.listEquation(initialEquationList);
      initialVars = BackendVariable.listVar1(initialVariableList);
      //BackendDump.dumpBackendDAEEqnList(initialEquationList, "initial equations", false);
      //BackendDump.dumpBackendDAEVarList(initialVariableList, "initial vars");
      
      initEqSystem = BackendDAE.EQSYSTEM(initialVars, initialEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{});
      
      // redirect output to bidir
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays
      DAE = collapseIndependentBlocks(DAE);
      BackendDAE.DAE(eqs={BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, shared=shared) = DAE;
      orderedVarList = BackendVariable.varList(orderedVars);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 1");
      orderedVarList = redirectOutputToBiDir(orderedVarList);
      //BackendDump.dumpBackendDAEVarList(orderedVarList, "initial vars 2");
      orderedVars = BackendVariable.listVar1(orderedVarList);
      
      // add initial equations and $res-variables
      DAE = BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars, orderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{}), initEqSystem}, shared);
      DAE = BackendDAEUtil.copyBackendDAE(DAE);                         // to avoid side effects from arrays

      DAE = collapseIndependentBlocks(DAE);                             // merge everything together
      DAE = BackendDAEUtil.transformBackendDAE(DAE, SOME((BackendDAE.NO_INDEX_REDUCTION(), BackendDAE.EXACT())), NONE(), SOME("dummyDerivative"));  // calculate matching
      
      // preparing all needed variables
      BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars=orderedVars, orderedEqs=orderedEqs)}, BackendDAE.SHARED(knownVars=knownVars)) = DAE;

      orderedVarList = BackendVariable.varList(orderedVars);
      orderedVarCrefList = List.map(orderedVarList, BackendVariable.varCref);
      knownVarList = BackendVariable.varList(knownVars);
      knownVarCrefList = List.map(knownVarList, BackendVariable.varCref);
      states = BackendVariable.getAllStateVarFromVariables(orderedVars);
      inputs = List.select(knownVarList, BackendVariable.isInput);
      parameters = List.select(knownVarList, BackendVariable.isParam);
      outputs = List.select(orderedVarList, BackendVariable.isVarOnTopLevelAndOutput);

      (sparsityPattern, _) = generateSparsePattern(DAE, states, outputs);
    then (sparsityPattern, DAE);
    
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateInitialMatricesSparsityPattern failed"});
    then fail();
  end matchcontinue;
end generateInitialMatricesSparsityPattern;




/*
 * Symbolic Jacobian subsection
 *
 */ 
public function generateSymbolicJacobianPast
  input BackendDAE.BackendDAE inBackendDAE;
  output BackendDAE.BackendDAE outBackendDAE;
protected 
  BackendDAE.EqSystems eqs;
  BackendDAE.Shared shared;
  BackendDAE.SymbolicJacobian symJacA;
  BackendDAE.SparsePattern sparsePattern;
  BackendDAE.SparseColoring sparseColoring;    
algorithm
  System.realtimeTick(BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
  BackendDAE.DAE(eqs=eqs,shared=shared) := inBackendDAE;
  (symJacA , sparsePattern, sparseColoring ):= createSymbolicJacobianforStates(inBackendDAE);
  shared := BackendDAEUtil.addBackendDAESharedJacobian(symJacA, sparsePattern, sparseColoring, shared);
  outBackendDAE := BackendDAE.DAE(eqs,shared);
  _ := Flags.enableDebug(Flags.JACOBIAN);
  _ := System.realtimeTock(BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
end generateSymbolicJacobianPast;

public function generateSymbolicLinearizationPast
  input BackendDAE.BackendDAE inBackendDAE;
  output BackendDAE.BackendDAE outBackendDAE;
protected 
  BackendDAE.EqSystems eqs;
  BackendDAE.Shared shared;
  BackendDAE.SymbolicJacobians linearModelMatrixes;
algorithm
  System.realtimeTick(BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
  BackendDAE.DAE(eqs=eqs,shared=shared) := inBackendDAE;
  linearModelMatrixes := createLinearModelMatrixes(inBackendDAE);
  shared := BackendDAEUtil.addBackendDAESharedJacobians(linearModelMatrixes, shared);
  outBackendDAE := BackendDAE.DAE(eqs,shared);
  _ := Flags.enableDebug(Flags.JACOBIAN);
  _ := System.realtimeTock(BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
end generateSymbolicLinearizationPast;

protected function createSymbolicJacobianforStates
" fuction creates symbolic jacobian
  all functionODE equation are differentiated 
  with respect to the states.
  
  author: wbraun"
  input BackendDAE.BackendDAE inBackendDAE;
  output BackendDAE.SymbolicJacobian outJacobian;
  output BackendDAE.SparsePattern outSparsePattern;
  output BackendDAE.SparseColoring outSparseColoring;  
algorithm
  (outJacobian, outSparsePattern, outSparseColoring) :=
  matchcontinue (inBackendDAE)
    local
      BackendDAE.BackendDAE backendDAE, backendDAE2;
      
      list<BackendDAE.Var>  varlst, knvarlst,  states, inputvars, paramvars;
      list<DAE.ComponentRef> comref_vars,comref_knvars;
      
      BackendDAE.Variables v,kv;
      BackendDAE.EquationArray e;

      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;

    case (backendDAE)      
      equation
        
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> start generate system for matrix A time : " +& realString(clock()) +& "\n");
        
        backendDAE2 = BackendDAEUtil.copyBackendDAE(backendDAE);
        backendDAE2 = collapseIndependentBlocks(backendDAE2);
        backendDAE2 = BackendDAEUtil.transformBackendDAE(backendDAE2,SOME((BackendDAE.NO_INDEX_REDUCTION(),BackendDAE.EXACT())),NONE(),SOME("dummyDerivative"));
        BackendDAE.DAE({syst as BackendDAE.EQSYSTEM(orderedVars = v,orderedEqs = e)},shared as BackendDAE.SHARED(knownVars = kv)) = backendDAE2;
        
        /*
        (blt_states, _) = BackendDAEUtil.generateStatePartition(syst);
        
        newEqns = BackendEquation.emptyEqns();
        newVars = BackendVariable.emptyVars();
        (newEqns, newVars) = BackendDAEUtil.splitoutEquationAndVars(blt_states,e,v,newEqns,newVars);
        backendDAE2 = BackendDAE.DAE(BackendDAE.EQSYSTEM(newVars,newEqns,NONE(),NONE(),BackendDAE.NO_MATCHING())::{},shared);
        backendDAE2 = BackendDAEUtil.transformBackendDAE(backendDAE2,SOME((BackendDAE.NO_INDEX_REDUCTION(),BackendDAE.EXACT())),NONE(),SOME("dummyDerivative"));
        */ 
        // Prepare all needed variables
        varlst = BackendVariable.varList(v);
        comref_vars = List.map(varlst,BackendVariable.varCref);
        knvarlst = BackendVariable.varList(kv);
        comref_knvars = List.map(knvarlst,BackendVariable.varCref);
        states = BackendVariable.getAllStateVarFromVariables(v);
        inputvars = List.select(knvarlst,BackendVariable.isInput);
        paramvars = List.select(knvarlst, BackendVariable.isParam);

        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> prepared vars for symbolic matrix A time: " +& realString(clock()) +& "\n");
        (outJacobian, outSparsePattern, outSparseColoring)  = createJacobian(backendDAE2,states,BackendVariable.listVar1(states),BackendVariable.listVar1(inputvars),BackendVariable.listVar1(paramvars),BackendVariable.listVar1(states),varlst,"A");
        
      then
        (outJacobian, outSparsePattern, outSparseColoring);
    else
      equation
        Error.addMessage(Error.INTERNAL_ERROR, {"Generation of symbolic Jacobian Matrix code failed. Function: BackendDAEOpimize.createSymcolicaJacobianforStates"});
      then
        fail();
  end matchcontinue;
end createSymbolicJacobianforStates;

protected function createLinearModelMatrixes
"fuction creates the linear model matrices column-wise
 author: wbraun"
  input BackendDAE.BackendDAE inBackendDAE;
  output BackendDAE.SymbolicJacobians outJacobianMatrixes;
algorithm
  outJacobianMatrixes :=
  matchcontinue (inBackendDAE)
    local
      BackendDAE.BackendDAE backendDAE,backendDAE2;
      
      list<BackendDAE.Var>  varlst, knvarlst,  states, inputvars, inputvars2, outputvars, paramvars;
      list<DAE.ComponentRef> comref_states, comref_inputvars, comref_outputvars, comref_vars, comref_knvars;
      
      BackendDAE.Variables v,kv,statesarr,inputvarsarr,paramvarsarr,outputvarsarr;
      BackendDAE.EquationArray e;
      
      BackendDAE.SymbolicJacobians linearModelMatrices;
      BackendDAE.SymbolicJacobian linearModelMatrix;
      
      BackendDAE.SparsePattern sparsePattern;
      BackendDAE.SparseColoring sparseColoring;  
      
    case (backendDAE)
      equation
        backendDAE2 = BackendDAEUtil.copyBackendDAE(backendDAE);
        backendDAE2 = collapseIndependentBlocks(backendDAE2);
        backendDAE2 = BackendDAEUtil.transformBackendDAE(backendDAE2,SOME((BackendDAE.NO_INDEX_REDUCTION(),BackendDAE.EXACT())),NONE(),SOME("dummyDerivative"));
        BackendDAE.DAE({BackendDAE.EQSYSTEM(orderedVars = v,orderedEqs = e)},BackendDAE.SHARED(knownVars = kv)) = backendDAE2;
        
        // Prepare all needed variables
        varlst = BackendVariable.varList(v);
        comref_vars = List.map(varlst,BackendVariable.varCref);
        knvarlst = BackendVariable.varList(kv);
        comref_knvars = List.map(knvarlst,BackendVariable.varCref);
        states = BackendVariable.getAllStateVarFromVariables(v);
        inputvars = List.select(knvarlst,BackendVariable.isInput);
        paramvars = List.select(knvarlst, BackendVariable.isParam);
        inputvars2 = List.select(knvarlst,BackendVariable.isVarOnTopLevelAndInput);
        outputvars = List.select(varlst,BackendVariable.isVarOnTopLevelAndOutput);
        
        comref_states = List.map(states,BackendVariable.varCref);
        comref_inputvars = List.map(inputvars2,BackendVariable.varCref);
        comref_outputvars = List.map(outputvars,BackendVariable.varCref);
        
        statesarr = BackendVariable.listVar1(states);
        inputvarsarr = BackendVariable.listVar1(inputvars);
        paramvarsarr = BackendVariable.listVar1(paramvars);
        outputvarsarr = BackendVariable.listVar1(outputvars);
        
        // Differentiate the System w.r.t states for matrices A
        (linearModelMatrix, sparsePattern, sparseColoring) = createJacobian(backendDAE2,states,statesarr,inputvarsarr,paramvarsarr,statesarr,varlst,"A");
        linearModelMatrices = {(SOME(linearModelMatrix),sparsePattern,sparseColoring)};
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated system for matrix A time: " +& realString(clock()) +& "\n");
  
        
        // Differentiate the System w.r.t inputs for matrices B
        (linearModelMatrix, sparsePattern, sparseColoring) = createJacobian(backendDAE2,inputvars2,statesarr,inputvarsarr,paramvarsarr,statesarr,varlst,"B");
        linearModelMatrices = listAppend(linearModelMatrices,{(SOME(linearModelMatrix),sparsePattern,sparseColoring)});
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated system for matrix B time: " +& realString(clock()) +& "\n");


        // Differentiate the System w.r.t states for matrices C
        (linearModelMatrix, sparsePattern, sparseColoring) = createJacobian(backendDAE2,states,statesarr,inputvarsarr,paramvarsarr,outputvarsarr,varlst,"C");
        linearModelMatrices = listAppend(linearModelMatrices,{(SOME(linearModelMatrix),sparsePattern,sparseColoring)});
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated system for matrix C time: " +& realString(clock()) +& "\n");

        
        // Differentiate the System w.r.t inputs for matrices D
        (linearModelMatrix, sparsePattern, sparseColoring) = createJacobian(backendDAE2,inputvars2,statesarr,inputvarsarr,paramvarsarr,outputvarsarr,varlst,"D");
        linearModelMatrices = listAppend(linearModelMatrices,{(SOME(linearModelMatrix),sparsePattern,sparseColoring)});
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated system for matrix D time: " +& realString(clock()) +& "\n");

      then
        linearModelMatrices;
    else
      equation
        Error.addMessage(Error.INTERNAL_ERROR, {"Generation of LinearModel Matrices failed. Function: BackendDAEOpimize.createLinearModelMatrixes"});
      then
        fail();
  end matchcontinue;
end createLinearModelMatrixes;

public function createJacobian "function createJacobian
  author: wbraun
  helper fuction of createSymbolicJacobian*"
  input BackendDAE.BackendDAE inBackendDAE;
  input list<BackendDAE.Var> inDiffVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParameterVars;
  input BackendDAE.Variables inDifferentiatedVars;
  input list<BackendDAE.Var> inVars;
  input String inName;
  output BackendDAE.SymbolicJacobian outJacobian;
  output BackendDAE.SparsePattern outSparsePattern;
  output BackendDAE.SparseColoring outSparseColoring;
algorithm
  (outJacobian, outSparsePattern, outSparseColoring) :=
  matchcontinue (inBackendDAE,inDiffVars,inStateVars,inInputVars,inParameterVars,inDifferentiatedVars,inVars,inName)
    local
      BackendDAE.BackendDAE backendDAE;
      
      list<DAE.ComponentRef> comref_vars, comref_seedVars, comref_differentiatedVars;
      
      BackendDAE.Shared shared;
      BackendDAE.Variables  knvars, knvars1;
      list<BackendDAE.Var> diffedVars, diffVarsTmp, seedlst, knvarsTmp;
      String s,s1;
      
      BackendDAE.SparsePattern sparsepattern;
      BackendDAE.SparseColoring colsColors;
      
    case (_,_,_,_,_,_,_,_)
      equation
        
        diffedVars = BackendVariable.varList(inDifferentiatedVars);
        s =  intString(listLength(diffedVars));
        comref_differentiatedVars = List.map(diffedVars, BackendVariable.varCref);
        
        comref_vars = List.map(inDiffVars, BackendVariable.varCref);
        seedlst = List.map1(comref_vars, createSeedVars, (inName,false));
        comref_seedVars = List.map(seedlst, BackendVariable.varCref);
        s1 =  intString(listLength(inVars));
 
        Debug.execStat("analytical Jacobians -> starting to generate the jacobian. DiffVars:"
                       +& s +& " diffed equations: " +&  s1 +& "\n", BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
                       
        // Differentiate the ODE system w.r.t states for jacobian
        (backendDAE as BackendDAE.DAE(shared=shared)) = generateSymbolicJacobian(inBackendDAE, comref_vars, inDifferentiatedVars, BackendVariable.listVar1(seedlst), inStateVars, inInputVars, inParameterVars, inName);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated equations for Jacobian " +& inName +& " time: " +& realString(clock()) +& "\n");
        
        knvars1 = BackendVariable.daeKnVars(shared);
        knvarsTmp = BackendVariable.varList(knvars1);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> sorted know temp vars(" +& intString(listLength(knvarsTmp)) +& ") for Jacobian DAE time: " +& realString(clock()) +& "\n");
        
        (backendDAE as BackendDAE.DAE(shared=shared)) = optimizeJacobianMatrix(backendDAE,comref_differentiatedVars,comref_vars);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> generated Jacobian DAE time: " +& realString(clock()) +& "\n");
        
        knvars = BackendVariable.daeKnVars(shared);
        diffVarsTmp = BackendVariable.varList(knvars);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> sorted know diff vars(" +& intString(listLength(diffVarsTmp)) +& ") for Jacobian DAE time: " +& realString(clock()) +& "\n");
        (_,knvarsTmp,_) = List.intersection1OnTrue(diffVarsTmp, knvarsTmp, BackendVariable.varEqual);
        Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> sorted know vars(" +& intString(listLength(knvarsTmp)) +& ") for Jacobian DAE time: " +& realString(clock()) +& "\n");
        knvars = BackendVariable.listVar1(knvarsTmp);
        backendDAE = BackendDAEUtil.addBackendDAEKnVars(knvars,backendDAE);
        Debug.execStat("analytical Jacobians -> generated optimized jacobians", BackendDAE.RT_CLOCK_EXECSTAT_JACOBIANS);
        
        // generate sparse pattern
        (sparsepattern,colsColors) = generateSparsePattern(inBackendDAE, inDiffVars, diffedVars);
     then
        ((backendDAE, inName, inDiffVars, diffedVars, inVars), sparsepattern, colsColors);
    else
      equation
        Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.createJacobian failed"});
      then
        fail();
  end matchcontinue;
end createJacobian;

public function optimizeJacobianMatrix
  // function: optimizeJacobianMatrix
  // author: wbraun
  input BackendDAE.BackendDAE inBackendDAE;
  input list<DAE.ComponentRef> inComRef1; // eqnvars
  input list<DAE.ComponentRef> inComRef2; // vars to differentiate 
  output BackendDAE.BackendDAE outJacobian;
algorithm 
  outJacobian :=
    matchcontinue (inBackendDAE,inComRef1,inComRef2)
    local
      BackendDAE.BackendDAE backendDAE, backendDAE2;
      BackendDAE.Variables v;
      BackendDAE.EquationArray e;
      
      BackendDAE.Shared shared;
      array<Integer> ea;
      
      Option<BackendDAE.IncidenceMatrix> om,omT;
      Boolean b;
      BackendDAE.StateSets stateSets;
      
      case (backendDAE as BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=v,orderedEqs=e,m=om,mT=omT,stateSets=stateSets)::{},shared),{},_)
        equation
          v = BackendVariable.listVar({});
          ea = listArray({});
        then (BackendDAE.DAE(BackendDAE.EQSYSTEM(v,e,om,omT,BackendDAE.MATCHING(ea,ea,{}),stateSets)::{},shared));
      case (backendDAE as BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=v,orderedEqs=e,m=om,mT=omT,stateSets=stateSets)::{},shared),_,{})
        equation
          v = BackendVariable.listVar({});
          ea = listArray({});
        then (BackendDAE.DAE(BackendDAE.EQSYSTEM(v,e,om,omT,BackendDAE.MATCHING(ea,ea,{}),stateSets)::{},shared));
      case (backendDAE,_,_)
        equation
          Debug.fcall(Flags.JAC_DUMP, print, "analytical Jacobians -> optimize jacobians time: " +& realString(clock()) +& "\n");
          
          b = Flags.disableDebug(Flags.EXEC_STAT);

          backendDAE2 = BackendDAEUtil.getSolvedSystemforJacobians(backendDAE,
                                                                   SOME({"removeSimpleEquationsFast"}),
                                                                   NONE(),
                                                                   NONE(),
                                                                   SOME({"inlineArrayEqn",
                                                                         "constantLinearSystem",
                                                                         "removeSimpleEquations",
                                                                         "collapseIndependentBlocks"}));
          _ = Flags.set(Flags.EXEC_STAT, b);
          //Debug.fcall(Flags.JAC_DUMP2, BackendDump.bltdump, ("jacdump2",backendDAE2));
        then backendDAE2;
     else
       equation
         Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.optimizeJacobianMatrix failed"});
       then fail();
   end matchcontinue;
end optimizeJacobianMatrix;

public function generateSymbolicJacobian "function generateSymbolicJacobian
  author: lochel"
  input BackendDAE.BackendDAE inBackendDAE;
  input list<DAE.ComponentRef> inVars;      // wrt
  input BackendDAE.Variables indiffedVars;  // unknowns?
  input BackendDAE.Variables inseedVars;    //
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input String inMatrixName;
  output BackendDAE.BackendDAE outJacobian;
algorithm
  outJacobian := matchcontinue(inBackendDAE, inVars, indiffedVars, inseedVars, inStateVars, inInputVars, inParamVars, inMatrixName)
    local
      BackendDAE.BackendDAE bDAE;
      DAE.FunctionTree functions;
      list<DAE.ComponentRef> vars, comref_diffvars;
      DAE.ComponentRef x;
      String dummyVarName;
      BackendDAE.Variables stateVars;
      BackendDAE.Variables inputVars;
      BackendDAE.Variables paramVars;
      BackendDAE.Variables diffedVars;
      BackendDAE.BackendDAE jacobian;
      
      // BackendDAE
      BackendDAE.Variables orderedVars, jacOrderedVars; // ordered Variables, only states and alg. vars
      BackendDAE.Variables knownVars, jacKnownVars; // Known variables, i.e. constants and parameters
      BackendDAE.Variables jacExternalObjects; // External object variables
      BackendDAE.Variables jacAliasVars; // mappings of alias-variables to real-variables
      BackendDAE.EquationArray orderedEqs, jacOrderedEqs; // ordered Equations
      BackendDAE.EquationArray removedEqs, jacRemovedEqs; // Removed equations a=b
      BackendDAE.EquationArray jacInitialEqs; // Initial equations
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      BackendDAE.EventInfo jacEventInfo; // eventInfo
      BackendDAE.ExternalObjectClasses jacExtObjClasses; // classes of external objects, contains constructor & destructor
      // end BackendDAE
      
      list<BackendDAE.Var> derivedVariables,diffvars;
      list<BackendDAE.Equation> derivedEquations;
      list<list<BackendDAE.Equation>> derivedEquationslst;
      
      
      Env.Cache cache;
      Env.Env env;      
      
      String matrixName;
      array<Integer> ass2;

    case(BackendDAE.DAE(shared=BackendDAE.SHARED(cache=cache,env=env)), {}, _, _, _, _, _, _) equation
      jacOrderedVars = BackendVariable.emptyVars();
      jacKnownVars = BackendVariable.emptyVars();
      jacExternalObjects = BackendVariable.emptyVars();
      jacAliasVars =  BackendVariable.emptyVars();
      jacOrderedEqs = BackendEquation.emptyEqns();
      jacRemovedEqs = BackendEquation.emptyEqns();
      jacInitialEqs = BackendEquation.emptyEqns();
      constrs = listArray({});
      clsAttrs = listArray({});
      functions = DAEUtil.avlTreeNew();
      jacEventInfo = BackendDAE.EVENT_INFO({}, {}, {}, {}, 0, 0);
      jacExtObjClasses = {};
      
      jacobian = BackendDAE.DAE({BackendDAE.EQSYSTEM(jacOrderedVars, jacOrderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{})}, BackendDAE.SHARED(jacKnownVars, jacExternalObjects, jacAliasVars, jacInitialEqs, jacRemovedEqs, constrs, clsAttrs, cache, env, functions, jacEventInfo, jacExtObjClasses,BackendDAE.JACOBIAN(),{}));
    then jacobian;
     
    case(bDAE as BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=orderedVars,orderedEqs=orderedEqs,matching=BackendDAE.MATCHING(ass2=ass2))::{}, BackendDAE.SHARED(knownVars=knownVars, removedEqs=removedEqs ,cache=cache,env=env,  functionTree=functions)), vars, diffedVars, _, stateVars, inputVars, paramVars, matrixName) equation

      // Generate tmp varibales
      diffvars = BackendVariable.varList(orderedVars);
      dummyVarName = ("dummyVar" +& matrixName);
      x = DAE.CREF_IDENT(dummyVarName,DAE.T_REAL_DEFAULT,{});

      // differentiate the equation system
      Debug.fcall(Flags.JAC_DUMP, print, "*** analytical Jacobians -> derived all algorithms time: " +& realString(clock()) +& "\n");
      derivedEquationslst = deriveAll(BackendEquation.equationList(orderedEqs),arrayList(ass2), {x}, functions, inputVars, paramVars, stateVars, knownVars, orderedVars, vars, (matrixName,false), {});
      derivedEquations = List.flatten(derivedEquationslst);
      Debug.fcall(Flags.JAC_DUMP, print, "*** analytical Jacobians -> created all derived equation time: " +& realString(clock()) +& "\n");
      
      // create BackendDAE.DAE with derivied vars and equations
      
      // all variables for new equation system
      // d(ordered vars)/d(dummyVar) 
      diffvars = BackendVariable.varList(orderedVars);
      derivedVariables = creatallDiffedVars(diffvars, x, diffedVars, 0, (matrixName, false),{});

      jacOrderedVars = BackendVariable.listVar1(derivedVariables);
      // known vars: all variable from original system + seed
      jacKnownVars = BackendVariable.emptyVars();
      jacKnownVars = BackendVariable.mergeVariables(jacKnownVars, orderedVars);
      jacKnownVars = BackendVariable.mergeVariables(jacKnownVars, knownVars);
      jacKnownVars = BackendVariable.mergeVariables(jacKnownVars, inseedVars);
      (jacKnownVars,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(jacKnownVars, BackendVariable.setVarDirectionTpl, (DAE.INPUT()));
      jacExternalObjects = BackendVariable.emptyVars();
      jacAliasVars =  BackendVariable.emptyVars();
      jacOrderedEqs = BackendEquation.listEquation(derivedEquations);
      jacRemovedEqs = BackendEquation.emptyEqns();
      jacInitialEqs = BackendEquation.emptyEqns();
      constrs = listArray({});
      clsAttrs = listArray({});
      functions = DAEUtil.avlTreeNew();
      jacEventInfo = BackendDAE.EVENT_INFO({}, {}, {}, {}, 0, 0);
      jacExtObjClasses = {};
      
      jacobian = BackendDAE.DAE(BackendDAE.EQSYSTEM(jacOrderedVars, jacOrderedEqs, NONE(), NONE(), BackendDAE.NO_MATCHING(),{})::{}, BackendDAE.SHARED(jacKnownVars, jacExternalObjects, jacAliasVars, jacInitialEqs, jacRemovedEqs, constrs, clsAttrs, cache, env, functions, jacEventInfo, jacExtObjClasses, BackendDAE.JACOBIAN(),{}));
      
    then jacobian;
 
    case(bDAE as BackendDAE.DAE(BackendDAE.EQSYSTEM(orderedVars=orderedVars,orderedEqs=orderedEqs,matching=BackendDAE.MATCHING(ass2=ass2))::{}, BackendDAE.SHARED(knownVars=knownVars, removedEqs=removedEqs, functionTree=functions)), vars, diffedVars, _, stateVars, inputVars, paramVars, _) equation
      
      diffvars = BackendVariable.varList(orderedVars);
      (derivedVariables,comref_diffvars) = generateJacobianVars(diffvars, vars, (inMatrixName,false));
      Debug.fcall(Flags.JAC_DUMP, print, "*** analytical Jacobians -> created all derived vars: " +& "No. :" +& intString(listLength(comref_diffvars)) +& "time: " +& realString(clock()) +& "\n");
      derivedEquationslst = deriveAll(BackendEquation.equationList(orderedEqs),arrayList(ass2), vars, functions, inputVars, paramVars, stateVars, knownVars, orderedVars, comref_diffvars, (inMatrixName,false), {});
      derivedEquations = List.flatten(derivedEquationslst);
      false = (listLength(derivedVariables) == listLength(derivedEquations));
      Debug.fcall(Flags.JAC_DUMP, print, "*** analytical Jacobians -> failed vars are not equal to equations: " +& intString(listLength(derivedEquations)) +& " time: " +& realString(clock()) +& "\n");
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.generateSymbolicJacobian failed"});
    then fail();  
      
    else
     equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.generateSymbolicJacobian failed"});
    then fail();
  end matchcontinue;
end generateSymbolicJacobian;

public function createSeedVars
  // function: createSeedVars
  // author: wbraun
  input DAE.ComponentRef indiffVar;
  input tuple<String,Boolean> inMatrixName;
  output BackendDAE.Var outseedVar;
algorithm
  outseedVar := match(indiffVar,inMatrixName)
    local
      BackendDAE.Var  jacvar;
      DAE.ComponentRef derivedCref;
    case (_, _)
      equation 
        derivedCref = differentiateVarWithRespectToX(indiffVar, indiffVar, inMatrixName);
        jacvar = BackendDAE.VAR(derivedCref, BackendDAE.STATE_DER(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
      then jacvar;
  end match;
end createSeedVars;

protected function generateJacobianVars "function generateJacobianVars
  author: lochel"
  input list<BackendDAE.Var> inVars1;
  input list<DAE.ComponentRef> inVars2;
  input tuple<String,Boolean> inMatrixName;
  output list<BackendDAE.Var> outVars;
  output list<DAE.ComponentRef> outcrefVars;
algorithm
  (outVars, outcrefVars) := matchcontinue(inVars1, inVars2, inMatrixName)
  local
    BackendDAE.Var currVar;
    list<BackendDAE.Var> restVar, r1, r2, r;
    list<DAE.ComponentRef> vars2,res,res1,res2;
    
    case({}, _, _)
    then ({},{});
      
    case(currVar::restVar, vars2, _) equation
      (r1,res1) = generateJacobianVars2(currVar, vars2, inMatrixName);
      (r2,res2) = generateJacobianVars(restVar, vars2, inMatrixName);
      res = listAppend(res1, res2);
      r = listAppend(r1, r2);
    then (r,res);
      
    else
     equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateJacobianVars failed"});
    then fail();
  end matchcontinue;
end generateJacobianVars;

protected function generateJacobianVars2 "function generateJacobianVars2
  author: lochel"
  input BackendDAE.Var inVar1;
  input list<DAE.ComponentRef> inVars2;
  input tuple<String,Boolean> inMatrixName;
  output list<BackendDAE.Var> outVars;
  output list<DAE.ComponentRef> outcrefVars;
algorithm
  (outVars,outcrefVars) := matchcontinue(inVar1, inVars2, inMatrixName)
  local
    BackendDAE.Var var, r1;
    DAE.ComponentRef currVar, cref, derivedCref;
    list<DAE.ComponentRef> restVar,res,res1;
    list<BackendDAE.Var> r,r2;
    
    case(_, {}, _)
    then ({},{});
 
    // skip for dicrete variable
    case(var as BackendDAE.VAR(varName=cref,varKind=BackendDAE.DISCRETE()), currVar::restVar, _ ) equation
      (r2,res) = generateJacobianVars2(var, restVar, inMatrixName);
    then (r2,res);
    
    case(var as BackendDAE.VAR(varName=cref,varKind=BackendDAE.STATE()), currVar::restVar, _) equation
      cref = ComponentReference.crefPrefixDer(cref);
      derivedCref = differentiateVarWithRespectToX(cref, currVar, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.STATE_DER(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
      (r2,res1) = generateJacobianVars2(var, restVar, inMatrixName);
      res = listAppend({derivedCref}, res1);
      r = listAppend({r1}, r2);
    then (r,res);

    case(var as BackendDAE.VAR(varName=cref), currVar::restVar, _) equation
      derivedCref = differentiateVarWithRespectToX(cref, currVar, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.VARIABLE(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
      (r2,res1) = generateJacobianVars2(var, restVar, inMatrixName);
      res = listAppend({derivedCref}, res1);
      r = listAppend({r1}, r2);
    then (r,res);
      
    else
     equation
      Error.addMessage(Error.INTERNAL_ERROR, {"./Compiler/BackEnd/BackendDAEOptimize.mo: function generateJacobianVars2 failed"});
    then fail();
  end matchcontinue;
end generateJacobianVars2;

public function creatallDiffedVars
  // function: help function for creatallDiffedVars
  // author: wbraun
  input list<BackendDAE.Var> inVars;
  input DAE.ComponentRef inCref;
  input BackendDAE.Variables inAllVars;
  input Integer inIndex;
  input tuple<String,Boolean> inMatrixName;
  input list<BackendDAE.Var> iVars;
  output list<BackendDAE.Var> outVars;
algorithm
  outVars := matchcontinue(inVars, inCref,inAllVars,inIndex,inMatrixName,iVars)
  local
    BackendDAE.Var  r1,v1;
    DAE.ComponentRef currVar, cref, derivedCref;
    list<BackendDAE.Var> restVar;
    
    case({}, _, _, _, _,_)
    then listReverse(iVars);
    // skip for dicrete variable
    case(BackendDAE.VAR(varName=currVar,varKind=BackendDAE.DISCRETE())::restVar,cref,_,_, _, _) equation
     then
       creatallDiffedVars(restVar,cref,inAllVars,inIndex, inMatrixName,iVars);    
 
     case(BackendDAE.VAR(varName=currVar,varKind=BackendDAE.STATE())::restVar,cref,_,_, _, _) equation
      ({v1}, _) = BackendVariable.getVar(currVar, inAllVars);
      currVar = ComponentReference.crefPrefixDer(currVar);
      derivedCref = differentiateVarWithRespectToX(currVar, cref, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.STATE_DER(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
    then 
      creatallDiffedVars(restVar, cref, inAllVars, inIndex+1, inMatrixName,r1::iVars);
      
    case(BackendDAE.VAR(varName=currVar)::restVar,cref,_,_, _, _) equation
      ({v1}, _) = BackendVariable.getVar(currVar, inAllVars);
      derivedCref = differentiateVarWithRespectToX(currVar, cref, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.STATE_DER(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
    then 
      creatallDiffedVars(restVar, cref, inAllVars, inIndex+1, inMatrixName,r1::iVars); 
 
     case(BackendDAE.VAR(varName=currVar,varKind=BackendDAE.STATE())::restVar,cref,_,_, _, _) equation
      currVar = ComponentReference.crefPrefixDer(currVar);
      derivedCref = differentiateVarWithRespectToX(currVar, cref, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.VARIABLE(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
    then 
      creatallDiffedVars(restVar, cref, inAllVars, inIndex, inMatrixName,r1::iVars);
      
    case(BackendDAE.VAR(varName=currVar)::restVar,cref,_,_, _, _) equation
      derivedCref = differentiateVarWithRespectToX(currVar, cref, inMatrixName);
      r1 = BackendDAE.VAR(derivedCref, BackendDAE.VARIABLE(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
    then 
      creatallDiffedVars(restVar, cref, inAllVars, inIndex, inMatrixName,r1::iVars);
 
    else
     equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.creatallDiffedVars failed"});
    then fail();
  end matchcontinue;
end creatallDiffedVars;

protected function deriveAll "function deriveAll
  author: lochel"
  input list<BackendDAE.Equation> inEquations;
  input list<Integer> ass2;
  input list<DAE.ComponentRef> inVars;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inorderedVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  input list<list<BackendDAE.Equation>> inDerivedEquations;
  output list<list<BackendDAE.Equation>> outDerivedEquations;
algorithm
  outDerivedEquations := 
  matchcontinue(inEquations, ass2, inVars, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName, inDerivedEquations)
    local
      BackendDAE.Equation currEquation;
      DAE.FunctionTree functions;
      list<DAE.ComponentRef> vars;
      list<BackendDAE.Equation> restEquations, currDerivedEquations;
      BackendDAE.Variables inputVars, paramVars, stateVars, knownVars;
      list<Integer> ass2_1,solvedfor;
      
    case({},_, _, _, _, _, _, _, _, _, _, _) then listReverse(inDerivedEquations);
      
    case(currEquation::restEquations,_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _, _)
      equation
      //Debug.fcall(Flags.JAC_DUMP_EQN, print, "Derive Equation! Left on Stack: " +& intString(listLength(restEquations)) +& "\n");
      //Debug.fcall(Flags.JAC_DUMP_EQN, BackendDump.printEquationList, {currEquation});
      //Debug.fcall(Flags.JAC_DUMP_EQN, print, "\n");
      //dummycref = ComponentReference.makeCrefIdent("$pDERdummy", DAE.T_REAL_DEFAULT, {});
      //Debug.fcall(Flags.JAC_DUMP_EQN,print, "*** analytical Jacobians -> derive one equation: " +& realString(clock()) +& "\n" );
      (solvedfor,ass2_1) = List.split(ass2, BackendEquation.equationSize(currEquation));
      currDerivedEquations = derive(currEquation, solvedfor, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName);
      //Debug.fcall(Flags.JAC_DUMP_EQN, BackendDump.printEquationList, currDerivedEquations);
      //Debug.fcall(Flags.JAC_DUMP_EQN, print, "\n");
      //Debug.fcall(Flags.JAC_DUMP_EQN,print, "*** analytical Jacobians -> created other equations from that: " +& realString(clock()) +& "\n" );
     then
       deriveAll(restEquations, ass2_1, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName, currDerivedEquations::inDerivedEquations);

    else
     equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.deriveAll failed"});
    then fail();
  end matchcontinue;
end deriveAll;

protected function derive "function derive
  author: lochel"
  input BackendDAE.Equation inEquation;
  input list<Integer> solvedfor;
  input list<DAE.ComponentRef> inVar;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inorderedVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<BackendDAE.Equation> outDerivedEquations;
algorithm
  outDerivedEquations := matchcontinue(inEquation, solvedfor, inVar, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName)
    local
      BackendDAE.Equation currEquation;
      list<BackendDAE.Equation> derivedEqns;
      DAE.FunctionTree functions;
      DAE.ComponentRef cref;
      DAE.Exp exp,lhs, rhs;
      list<DAE.ComponentRef> vars, crefs;
      list<DAE.Exp> lhs_, rhs_, exps;
      DAE.ElementSource source;
      BackendDAE.Variables inputVars, paramVars, stateVars, knownVars;
      Integer size;
      DAE.Algorithm alg;
      list<DAE.Algorithm> algs;
      list<Integer> ds;
      list<Option<Integer>> ad;
      list<list<DAE.Subscript>> subslst;
      list<BackendDAE.Var> solvedvars;
      String dumpBuffer;

    case(currEquation as BackendDAE.WHEN_EQUATION(size=_),_, vars, functions, inputVars, paramVars, stateVars, knownVars,  _, _, _) equation
      Debug.fcall(Flags.JAC_DUMP, print,"BackendDAEOptimize.derive: WHEN_EQUATION has been removed.\n");
    then {};
    
    //remove dicrete Equation  
    case(currEquation,_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _) equation
      solvedvars = List.map1r(solvedfor,BackendVariable.getVarAt,inorderedVars);
      List.mapAllValue(solvedvars, BackendVariable.isVarDiscrete, true);
      Debug.fcall(Flags.JAC_DUMP, print,"BackendDAEOptimize.derive: discrete equation has been removed.\n");
    then {};

    case(currEquation as BackendDAE.EQUATION(exp=lhs, scalar=rhs, source=source),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _,  _, _) equation
      lhs_ = differentiateWithRespectToXVec(lhs, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName);
      rhs_ = differentiateWithRespectToXVec(rhs, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName);
      derivedEqns = List.threadMap1(lhs_, rhs_, BackendEquation.generateEQUATION, source);
    then derivedEqns;
      
    case(currEquation as BackendDAE.ARRAY_EQUATION(dimSize=ds,left=lhs,right=rhs,source=source),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _) equation
        ad = List.map(ds,Util.makeOption);
        subslst = BackendDAEUtil.arrayDimensionsToRange(ad);
        subslst = BackendDAEUtil.rangesToSubscripts(subslst);
        lhs_ = List.map1r(subslst,Expression.applyExpSubscripts,lhs);
        lhs_ = ExpressionSimplify.simplifyList(lhs_, {});
        rhs_ = List.map1r(subslst,Expression.applyExpSubscripts,rhs);
        rhs_ = ExpressionSimplify.simplifyList(rhs_, {});
    then
      deriveLst(lhs_,rhs_,source,vars, functions, inputVars, paramVars, stateVars, knownVars,inorderedVars, inDiffVars, inMatrixName, {});
      
    case(currEquation as BackendDAE.SOLVED_EQUATION(componentRef=cref, exp=exp, source=source),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _) equation
      crefs = List.map2(vars,differentiateVarWithRespectToXR,cref, inMatrixName);
      exps = differentiateWithRespectToXVec(exp, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName);
      derivedEqns = List.threadMap1(crefs, exps, createSolvedEqn, source);
    then derivedEqns;
      
    case(currEquation as BackendDAE.RESIDUAL_EQUATION(exp=exp, source=source),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _) equation
      exps = differentiateWithRespectToXVec(exp, vars, functions, inputVars, paramVars, stateVars, knownVars, inorderedVars, inDiffVars, inMatrixName);
      derivedEqns = List.map1(exps, createResidualEqn, source);
    then derivedEqns;
      
    case(currEquation as BackendDAE.ALGORITHM(size=size,alg=alg, source=source),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _)
    equation
      algs = deriveOneAlg(alg,vars,functions,inputVars,paramVars,stateVars,knownVars,inorderedVars,0,inDiffVars,inMatrixName);
      derivedEqns = List.map2(algs, createAlgorithmEqn, size, source);
    then derivedEqns;

    case(currEquation as BackendDAE.COMPLEX_EQUATION(source=_),_, vars, functions, inputVars, paramVars, stateVars, knownVars, _, _, _) equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.derive failed: COMPLEX_EQUATION-case"});
    then fail();
    
    case(currEquation, _, _, _, _, _, _, _, _, _, _) equation
      dumpBuffer = "BackendDAEOptimize.derive failed: " +& BackendDump.equationString(currEquation);
      Error.addMessage(Error.INTERNAL_ERROR, {dumpBuffer});
    then fail();
      
    else equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.derive failed"});
    then fail();
  end matchcontinue;
end derive;

protected function deriveLst "function derivelst
  author: Frenkel TUD
  helper for derive to handle array equations"
  input list<DAE.Exp> lhslst;
  input list<DAE.Exp> rhslst;
  input DAE.ElementSource source;
  input list<DAE.ComponentRef> inVars;
  input DAE.FunctionTree functions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inorderedVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  input list<BackendDAE.Equation> inDerivedEquations;
  output list<BackendDAE.Equation> outDerivedEquations;
algorithm
  outDerivedEquations := match(lhslst, rhslst, source, inVars, functions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName, inDerivedEquations)
    local
      list<BackendDAE.Equation> derivedEqns;
      DAE.Exp lhs, rhs;
      list<DAE.Exp> lhsrest,rhsrest,lhs_,rhs_;
    
    case({},{},_,_,_,_,_,_,_,_,_,_,_) then inDerivedEquations;
      
    case(lhs::lhsrest,rhs::rhsrest,_,_,_,_,_,_,_,_,_,_,_)
      equation
        lhs_ = differentiateWithRespectToXVec(lhs, inVars, functions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName);
        rhs_ = differentiateWithRespectToXVec(rhs, inVars, functions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName);
        derivedEqns = List.threadMap1(lhs_, rhs_, BackendEquation.generateEQUATION, source);
        derivedEqns = listAppend(inDerivedEquations,derivedEqns);
      then 
        deriveLst(lhsrest,rhsrest, source, inVars, functions, inInputVars, inParamVars, inStateVars, inKnownVars, inorderedVars, inDiffVars, inMatrixName, derivedEqns);
 
  end match;
end deriveLst;

protected function createSolvedEqn
  input DAE.ComponentRef inCref;
  input DAE.Exp inRHS;
  input DAE.ElementSource Source;
  output BackendDAE.Equation outEqn;
algorithm 
  outEqn := BackendDAE.SOLVED_EQUATION(inCref,inRHS,Source,false);
end createSolvedEqn;

protected function createResidualEqn
  input DAE.Exp inRHS;
  input DAE.ElementSource Source;
  output BackendDAE.Equation outEqn;
algorithm 
  outEqn := BackendDAE.RESIDUAL_EQUATION(inRHS, Source, false);
end createResidualEqn;

protected function createAlgorithmEqn
  input DAE.Algorithm Alg;
  input Integer Size;
  input DAE.ElementSource Source;
  output BackendDAE.Equation outEqn;
algorithm 
  outEqn := BackendDAE.ALGORITHM(Size, Alg, Source);
end createAlgorithmEqn;

public function differentiateVarWithRespectToX "function differentiateVarWithRespectToX
  author: lochel"
  input DAE.ComponentRef inCref;
  input DAE.ComponentRef inX;
  input tuple<String,Boolean> inMatrixName;
  //input list<BackendDAE.Var> inStateVars;
  output DAE.ComponentRef outCref;
algorithm
  outCref := matchcontinue(inCref, inX, inMatrixName)//, inStateVars)
    local
      DAE.ComponentRef cref, x;
      String id,str;
      String matrixName;
     /* replace the subscripts with strings because not all elements of the arrays may be derived, this avoid trouble when generate simulation code */
     case(cref, x, (matrixName,true)) 
      equation
        cref = ComponentReference.joinCrefs(ComponentReference.makeCrefIdent(BackendDAE.partialDerivativeNamePrefix, ComponentReference.crefType(cref), {}),cref);
        cref = ComponentReference.appendStringCref(matrixName, cref);
        cref = ComponentReference.joinCrefs(cref, x);
        cref = ComponentReference.replaceSubsWithString(cref);
      then 
        cref;
    case(cref, x, (matrixName,false))
      equation
        id = ComponentReference.printComponentRefStr(cref) +& BackendDAE.partialDerivativeNamePrefix +& matrixName +& "$P" +& ComponentReference.printComponentRefStr(x);
        id = Util.stringReplaceChar(id, ",", "$c");
        id = Util.stringReplaceChar(id, ".", "$P");
        id = Util.stringReplaceChar(id, "[", "$lB");
        id = Util.stringReplaceChar(id, "]", "$rB");
      then ComponentReference.makeCrefIdent(id, DAE.T_REAL_DEFAULT, {});
      
    case(cref, _, _)
      equation
        str = "BackendDAEOptimize.differentiateVarWithRespectToX failed: " +&  ComponentReference.printComponentRefStr(cref);
        Error.addMessage(Error.INTERNAL_ERROR, {str});
      then fail();
  end matchcontinue;
end differentiateVarWithRespectToX;

public function differentiateVarWithRespectToXR
"  function: differentiateVarWithRespectToXR
   author: wbraun
   This function create a differentiated ComponentReference. "
  input DAE.ComponentRef inX;
  input DAE.ComponentRef inCref;
  input tuple<String,Boolean> inMatrixName;
  output DAE.ComponentRef outCref;
algorithm
  outCref := differentiateVarWithRespectToX(inCref, inX, inMatrixName);
end differentiateVarWithRespectToXR;

protected function deriveExpListwrtstate
  input list<DAE.Exp> inExpList;
  input Integer inLengthExpList;
  input list<tuple<Integer,DAE.derivativeCond>> inConditios;
  input DAE.ComponentRef inState;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inAllVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<DAE.Exp> outExpList;
algorithm
  outExpList := matchcontinue(inExpList, inLengthExpList, inConditios, inState, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inAllVars, inDiffVars, inMatrixName)
    local
      DAE.ComponentRef x;
      DAE.Exp curr,r1;
      list<DAE.Exp> rest, r2;
      DAE.FunctionTree functions;
      Integer LengthExpList,n, argnum;
      list<tuple<Integer,DAE.derivativeCond>> conditions;
      BackendDAE.Variables inputVars, paramVars, stateVars, knownVars;
      list<DAE.ComponentRef> diffVars;
    case ({},_,_,_,_,_,_,_,_,_,_,_) then ({});
    case (curr::rest, LengthExpList, conditions, x, functions,inputVars, paramVars, stateVars, knownVars, _, diffVars,_) equation
      n = listLength(rest);
      argnum = LengthExpList - n;
      true = checkcondition(conditions,argnum);
      {r1} = differentiateWithRespectToXVec(curr, {x}, functions, inputVars, paramVars, stateVars, knownVars, inAllVars, diffVars,inMatrixName);
      r2 = deriveExpListwrtstate(rest,LengthExpList,conditions, x, functions,inputVars, paramVars, stateVars, knownVars, inAllVars, diffVars,inMatrixName);
    then (r1::r2);
    case (curr::rest, LengthExpList, conditions, x, functions,inputVars, paramVars, stateVars,knownVars, _, diffVars, _) equation
      r2 = deriveExpListwrtstate(rest,LengthExpList,conditions, x, functions,inputVars, paramVars, stateVars, knownVars, inAllVars, diffVars, inMatrixName);
    then r2;
  end matchcontinue;
end deriveExpListwrtstate;

protected function deriveExpListwrtstate2
  input list<DAE.Exp> inExpList;
  input Integer inLengthExpList;
  input DAE.ComponentRef inState;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inAllVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<DAE.Exp> outExpList;
algorithm
  outExpList := match(inExpList, inLengthExpList, inState, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inAllVars, inDiffVars, inMatrixName)
    local
      DAE.ComponentRef x;
      DAE.Exp curr,r1;
      list<DAE.Exp> rest, r2;
      DAE.FunctionTree functions;
      Integer LengthExpList,n, argnum;
      BackendDAE.Variables inputVars, paramVars, stateVars,knownVars;
      list<DAE.ComponentRef> diffVars;
    case ({}, _, _, _, _, _, _, _, _,_, _) then ({});
    case (curr::rest, LengthExpList, x, functions, inputVars, paramVars, stateVars, knownVars, _, diffVars, _) equation
      n = listLength(rest);
      argnum = LengthExpList - n;
      {r1} = differentiateWithRespectToXVec(curr, {x}, functions, inputVars, paramVars, stateVars, knownVars, inAllVars, diffVars, inMatrixName);
      r2 = deriveExpListwrtstate2(rest,LengthExpList, x, functions, inputVars, paramVars, stateVars, knownVars, inAllVars, diffVars, inMatrixName);
    then (r1::r2);
  end match;
end deriveExpListwrtstate2;

protected function checkcondition
  input list<tuple<Integer,DAE.derivativeCond>> inConditions;
  input Integer inArgs;
  output Boolean outBool;
algorithm
  outBool := matchcontinue(inConditions, inArgs)
    local
      list<tuple<Integer,DAE.derivativeCond>> rest;
      Integer i,nArgs;
      DAE.derivativeCond cond;
      Boolean res;
    case ({},_) then true;
    case((i,cond)::rest,nArgs) 
      equation
        equality(i = nArgs);
        cond = DAE.ZERO_DERIVATIVE();
      then false;
      case((i,cond)::rest,nArgs) 
       equation
         equality(i = nArgs);
         DAE.NO_DERIVATIVE(_) = cond;
       then false;
    case((i,cond)::rest,nArgs) 
      equation
        res = checkcondition(rest,nArgs);
      then res;
  end matchcontinue;
end checkcondition;

protected function partialAnalyticalDifferentiation
  input list<DAE.Exp> varExpList;
  input list<DAE.Exp> derVarExpList;
  input DAE.Exp functionCall;
  input Absyn.Path derFname;
  input Integer nDerArgs;
  output DAE.Exp outExp;
algorithm
  outExp := match(varExpList, derVarExpList, functionCall, derFname, nDerArgs)
    local
      DAE.Exp e, currVar, currDerVar, derFun;
      list<DAE.Exp> restVar, restDerVar, varExpList1Added, varExpListTotal;
      Integer nArgs1, nArgs2;
      DAE.CallAttributes attr;
    case ( _, {}, _, _, _) then (DAE.RCONST(0.0));
    case (currVar::restVar, currDerVar::restDerVar, DAE.CALL(expLst=varExpListTotal, attr=attr), _, _)
      equation
        e = partialAnalyticalDifferentiation(restVar, restDerVar, functionCall, derFname, nDerArgs);
        nArgs1 = listLength(varExpListTotal);
        nArgs2 = listLength(restDerVar);
        varExpList1Added = List.replaceAtWithFill(DAE.RCONST(0.0),nArgs1 + nDerArgs - 1, varExpListTotal ,DAE.RCONST(0.0));
        varExpList1Added = List.replaceAtWithFill(DAE.RCONST(1.0),nArgs1 + nDerArgs - (nArgs2 + 1), varExpList1Added,DAE.RCONST(0.0));
        derFun = DAE.CALL(derFname, varExpList1Added, attr);
      then DAE.BINARY(e, DAE.ADD(DAE.T_REAL_DEFAULT), DAE.BINARY(derFun, DAE.MUL(DAE.T_REAL_DEFAULT), currDerVar));
  end match;
end partialAnalyticalDifferentiation;

protected function partialNumericalDifferentiation
  input list<DAE.Exp> varExpList;
  input list<DAE.Exp> derVarExpList;
  input DAE.ComponentRef inState;
  input DAE.Exp functionCall;
  output DAE.Exp outExp;
algorithm
  outExp := match(varExpList, derVarExpList, inState, functionCall)
    local
      DAE.Exp e, currVar, currDerVar, derFun, delta, absCurr;
      list<DAE.Exp> restVar, restDerVar, varExpListHAdded, varExpListTotal;
      Absyn.Path fname;
      Integer nArgs1, nArgs2;
      DAE.CallAttributes attr;
    case ({}, _, _, _) then (DAE.RCONST(0.0));
    case (currVar::restVar, currDerVar::restDerVar, _, DAE.CALL(path=fname, expLst=varExpListTotal, attr=attr))
      equation
        e = partialNumericalDifferentiation(restVar, restDerVar, inState, functionCall);
        absCurr = DAE.LBINARY(DAE.RELATION(currVar,DAE.GREATER(DAE.T_REAL_DEFAULT),DAE.RCONST(1e-8),-1,NONE()),DAE.OR(DAE.T_BOOL_DEFAULT),DAE.RELATION(currVar,DAE.LESS(DAE.T_REAL_DEFAULT),DAE.RCONST(-1e-8),-1,NONE()));
        delta = DAE.IFEXP( absCurr, DAE.BINARY(currVar,DAE.MUL(DAE.T_REAL_DEFAULT),DAE.RCONST(1e-8)), DAE.RCONST(1e-8));
        nArgs1 = listLength(varExpListTotal);
        nArgs2 = listLength(restVar);
        varExpListHAdded = List.replaceAtWithFill(DAE.BINARY(currVar, DAE.ADD(DAE.T_REAL_DEFAULT),delta),nArgs1-(nArgs2+1), varExpListTotal,DAE.RCONST(0.0));
        derFun = DAE.BINARY(DAE.BINARY(DAE.CALL(fname, varExpListHAdded, attr), DAE.SUB(DAE.T_REAL_DEFAULT), DAE.CALL(fname, varExpListTotal, attr)), DAE.DIV(DAE.T_REAL_DEFAULT), delta);
      then DAE.BINARY(e, DAE.ADD(DAE.T_REAL_DEFAULT), DAE.BINARY(derFun, DAE.MUL(DAE.T_REAL_DEFAULT), currDerVar));
  end match;
end partialNumericalDifferentiation;

protected function deriveOneAlg "function deriveOneAlg
  author: lochel"
  input DAE.Algorithm inAlgorithm;
  input list<DAE.ComponentRef> inVars;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inAllVars;
  input Integer inAlgIndex;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<DAE.Algorithm> outDerivedAlgorithms;
algorithm
  outDerivedAlgorithms := match(inAlgorithm, inVars, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inAllVars, inAlgIndex, inDiffVars, inMatrixName)
    local
      DAE.Algorithm currAlg;
      list<DAE.Statement> statementLst, derivedStatementLst;
      DAE.ComponentRef currVar;
      list<DAE.ComponentRef> restVars;
      DAE.FunctionTree functions;
      BackendDAE.Variables inputVars;
      BackendDAE.Variables paramVars;
      BackendDAE.Variables stateVars;
      BackendDAE.Variables knownVars;
      list<DAE.ComponentRef> diffVars;
      Integer algIndex;
      list<DAE.Algorithm> rAlgs1, rAlgs2;
    case(_, {}, _, _, _, _, _, _, _,_, _) then {};
      
    case(currAlg as DAE.ALGORITHM_STMTS(statementLst=statementLst), currVar::restVars, functions, inputVars, paramVars, stateVars, knownVars, _, algIndex, diffVars, _)equation
      derivedStatementLst = differentiateAlgorithmStatements(statementLst, currVar, functions, inputVars, paramVars, stateVars, {}, knownVars, inAllVars, diffVars, inMatrixName);
      rAlgs1 = {DAE.ALGORITHM_STMTS(derivedStatementLst)};
      rAlgs2 = deriveOneAlg(currAlg, restVars, functions, inputVars, paramVars, stateVars, knownVars, inAllVars, algIndex, diffVars, inMatrixName);
      rAlgs1 = listAppend(rAlgs1, rAlgs2);
    then rAlgs1;
  end match;
end deriveOneAlg;

protected function differentiateAlgorithmStatements "function differentiateAlgorithmStatements
  author: lochel"
  input list<DAE.Statement> inStatements;
  input DAE.ComponentRef inVar;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input list<BackendDAE.Var> inControlVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inAllVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<DAE.Statement> outStatements;
algorithm
  outStatements := matchcontinue(inStatements, inVar, inFunctions, inInputVars, inParamVars, inStateVars, inControlVars, inKnownVars, inAllVars, inDiffVars, inMatrixName)
    local
      list<DAE.Statement> restStatements;
      DAE.ComponentRef var;
      DAE.FunctionTree functions;
      BackendDAE.Variables inputVars;
      BackendDAE.Variables paramVars;
      BackendDAE.Variables stateVars;
      list<BackendDAE.Var> controlVars;
      BackendDAE.Variables controlparaVars;
      BackendDAE.Variables knownVars;
      BackendDAE.Variables allVars;
      list<DAE.ComponentRef> diffVars;
      DAE.Statement currStatement;
      DAE.ElementSource source;
      list<DAE.Statement> derivedStatements1;
      list<DAE.Statement> derivedStatements2;
      DAE.Exp exp;
      DAE.Type type_;
      DAE.Exp lhs, rhs;
      DAE.Exp derivedLHS, derivedRHS;
      //list<DAE.Exp> derivedLHS, derivedRHS;
      DAE.Exp elseif_exp;
      list<DAE.Statement> statementLst,else_statementLst,elseif_statementLst;
      DAE.Else elseif_else_;
      Boolean iterIsArray;
      DAE.Ident ident;
      DAE.ComponentRef cref;
      BackendDAE.Var controlVar;
      list<DAE.Exp> lhsTuple;
      list<DAE.Exp> derivedLHSTuple;
      DAE.ElementSource source_;
      Integer index;
    case({}, _, _, _, _, _, _, _, _,_, _) then {};
      
    //remove dicrete Equation
    case ((currStatement as DAE.STMT_ASSIGN(type_=type_, exp1=lhs, exp=rhs,source=source_))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      true = BackendDAEUtil.isDiscreteExp(lhs,allVars,knownVars);
      true = BackendDAEUtil.isDiscreteExp(rhs,allVars,knownVars);
      Debug.fcall(Flags.JAC_DUMP,print,"BackendDAEOptimize.differentiateAlgorithmStatements: discrete equation has been removed.\n");
    then {};
 
    case((currStatement as DAE.STMT_ASSIGN(type_=type_, exp1=lhs, exp=rhs,source=source_))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _) 
    equation
      controlparaVars = BackendVariable.addVars(controlVars, paramVars);
      {derivedLHS} = differentiateWithRespectToXVec(lhs, {var}, functions, inputVars, controlparaVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      {derivedRHS} = differentiateWithRespectToXVec(rhs, {var}, functions, inputVars, controlparaVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_ASSIGN(type_, derivedLHS, derivedRHS, source_), currStatement};
      //derivedStatements1 = List.threadMap3(derivedLHS, derivedRHS, createDiffStatements, type_, currStatement, source);
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case ((currStatement as DAE.STMT_TUPLE_ASSIGN(type_=type_,exp=rhs,expExpLst=lhsTuple,source=source_))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars,  diffVars, _)
    equation
      controlparaVars = BackendVariable.addVars(controlVars, paramVars);
      {derivedLHSTuple} = List.map9(lhsTuple,differentiateWithRespectToXVec, {var}, functions, inputVars, controlparaVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      {derivedRHS} = differentiateWithRespectToXVec(rhs, {var}, functions, inputVars, controlparaVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_TUPLE_ASSIGN(type_, derivedLHSTuple, derivedRHS, source_), currStatement};
      //Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.differentiateAlgorithmStatements failed: DAE.STMT_TUPLE_ASSIGN"});
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case(DAE.STMT_ASSIGN_ARR(exp=rhs)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.differentiateAlgorithmStatements failed: DAE.STMT_ASSIGN_ARR"});
    then fail();
      
    case(DAE.STMT_IF(exp=exp, statementLst=statementLst, else_=DAE.NOELSE(), source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements1 = differentiateAlgorithmStatements(statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars,  diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_IF(exp, derivedStatements1, DAE.NOELSE(), source)};
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case(DAE.STMT_IF(exp=exp, statementLst=statementLst, else_=DAE.ELSEIF(exp=elseif_exp, statementLst=elseif_statementLst, else_=elseif_else_), source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements1 = differentiateAlgorithmStatements(statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements2 = differentiateAlgorithmStatements({DAE.STMT_IF(elseif_exp, elseif_statementLst, elseif_else_, source)}, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_IF(exp, derivedStatements1, DAE.ELSE(derivedStatements2), source)};
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case(DAE.STMT_IF(exp=exp, statementLst=statementLst, else_=DAE.ELSE(statementLst=else_statementLst), source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements1 = differentiateAlgorithmStatements(statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements2 = differentiateAlgorithmStatements(else_statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_IF(exp, derivedStatements1, DAE.ELSE(derivedStatements2), source)};
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case(DAE.STMT_FOR(type_=type_, iterIsArray=iterIsArray, iter=ident, index=index, range=exp, statementLst=statementLst, source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      cref = ComponentReference.makeCrefIdent(ident, DAE.T_INTEGER_DEFAULT, {});
      controlVar = BackendDAE.VAR(cref, BackendDAE.VARIABLE(), DAE.BIDIR(), DAE.NON_PARALLEL(), DAE.T_REAL_DEFAULT, NONE(), NONE(), {}, DAE.emptyElementSource, NONE(), NONE(), DAE.NON_CONNECTOR());
      controlVars = listAppend(controlVars, {controlVar});
      derivedStatements1 = differentiateAlgorithmStatements(statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);

      derivedStatements1 = {DAE.STMT_FOR(type_, iterIsArray, ident, index, exp, derivedStatements1, source)};
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;

    case(DAE.STMT_WHILE(exp=exp, statementLst=statementLst, source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements1 = differentiateAlgorithmStatements(statementLst, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = {DAE.STMT_WHILE(exp, derivedStatements1, source)};
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = listAppend(derivedStatements1, derivedStatements2);
    then derivedStatements1;
      
    case(DAE.STMT_WHEN(exp=exp)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      //derivedStatements1 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      Debug.fcall(Flags.JAC_DUMP,print,"BackendDAEOptimize.differentiateAlgorithmStatements: WHEN has been removed.\n");
    then {};
      
    case((currStatement as DAE.STMT_ASSERT(cond=exp))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars,  diffVars, _)
    equation
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars,  diffVars, inMatrixName);
      derivedStatements1 = currStatement::derivedStatements2;
    then derivedStatements1;
      
    case((currStatement as DAE.STMT_TERMINATE(msg=exp))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = currStatement::derivedStatements2;
    then derivedStatements1;
      
    case(DAE.STMT_REINIT(value=exp)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements1 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
    then derivedStatements1;
      
    case(DAE.STMT_NORETCALL(exp=exp, source=source)::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      // e2 = differentiateWithRespectToX(e1, var, functions, {}, {}, {});
      // derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions);
      // derivedStatements1 = listAppend({DAE.STMT_NORETCALL(e2, elemSrc)}, derivedStatements2);
    then fail();
      
    case((currStatement as DAE.STMT_RETURN(source=source))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = currStatement::derivedStatements2;
    then derivedStatements1;
      
    case((currStatement as DAE.STMT_BREAK(source=source))::restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, _)
    equation
      derivedStatements2 = differentiateAlgorithmStatements(restStatements, var, functions, inputVars, paramVars, stateVars, controlVars, knownVars, allVars, diffVars, inMatrixName);
      derivedStatements1 = currStatement::derivedStatements2;
    then derivedStatements1;
      
    case(_, _, _, _, _, _, _, _, _, _, _) equation
      Error.addMessage(Error.INTERNAL_ERROR, {"BackendDAEOptimize.differentiateAlgorithmStatements failed"});
    then fail();
  end matchcontinue;
end differentiateAlgorithmStatements;

protected function createDiffStatements
  input DAE.Exp inLHS;
  input DAE.Exp inRHS;
  input DAE.Type inType;
  input DAE.Statement inStmt;
  input DAE.ElementSource Source;
  output list<DAE.Statement> outEqn;
algorithm outEqn := match(inLHS,inRHS,inType,inStmt,Source)
  local
  case (inLHS,inRHS,inType,inStmt,Source) then {DAE.STMT_ASSIGN(inType, inLHS, inRHS, Source), inStmt};
 end match;
end createDiffStatements;

protected function differentiateWithRespectToXVec "function differentiateWithRespectToXVec
  author: wbraun"
  input DAE.Exp inExp;
  input list<DAE.ComponentRef> inX;
  input DAE.FunctionTree inFunctions;
  input BackendDAE.Variables inInputVars;
  input BackendDAE.Variables inParamVars;
  input BackendDAE.Variables inStateVars;
  input BackendDAE.Variables inKnownVars;
  input BackendDAE.Variables inAllVars;
  input list<DAE.ComponentRef> inDiffVars;
  input tuple<String,Boolean> inMatrixName;
  output list<DAE.Exp> outExp;
algorithm
  outExp := matchcontinue(inExp, inX, inFunctions, inInputVars, inParamVars, inStateVars, inKnownVars, inAllVars, inDiffVars, inMatrixName)
    local
      list<DAE.ComponentRef> xlist;
      list<DAE.Exp> dxlist,dxlist1,dxlist2;
      DAE.ComponentRef  cref;
      DAE.FunctionTree functions;
      DAE.Exp e1,  e2,  e;
      DAE.Type et;
      DAE.Operator op;
      
      Absyn.Path fname;
      
      list<DAE.Exp> expList1;
      list<list<DAE.Exp>> expListLst;
      Boolean  b;
      BackendDAE.Variables inputVars, paramVars, stateVars, knownVars, allVars;
      list<DAE.ComponentRef> diffVars;
      String str;
      BackendDAE.Var v1;
      Integer index;
      Option<tuple<DAE.Exp,Integer,Integer>> optionExpisASUB;
      list<DAE.Var> varLst;
      
    case(e as DAE.ICONST(_), xlist,functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        dxlist = createDiffListMeta(e,xlist,diffInt, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;
      
    case( e as DAE.RCONST(_), xlist,functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, _)
      equation
        dxlist = createDiffListMeta(e,xlist,diffRealZero, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;

    // d(time)/d(x)
    case(e as DAE.CREF(componentRef=(cref as DAE.CREF_IDENT(ident = "time",subscriptLst = {}))), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, _)
      equation
        dxlist = createDiffListMeta(e,xlist,diffRealZero, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;
          
  // case for Records
    case (e as DAE.CREF(componentRef=cref, ty = et as DAE.T_COMPLEX(varLst=varLst,complexClassType=ClassInf.RECORD(fname))), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        expList1 = List.map1(varLst,Expression.generateCrefsExpFromExpVar,cref);
        e1 = DAE.CALL(fname,expList1,DAE.CALL_ATTR(et,false,false,DAE.NO_INLINE(),DAE.NO_TAIL()));
      then
        differentiateWithRespectToXVec(e1,xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
    // case for arrays
    case (e as DAE.CREF(componentRef=cref, ty = et as DAE.T_ARRAY(dims=_)), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        ((e1,(_,true))) = BackendDAEUtil.extendArrExp((e,(NONE(),false)));
      then
        differentiateWithRespectToXVec(e1,xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);   
    
    case(e as DAE.CREF(componentRef=cref),xlist, functions, inputVars, paramVars, stateVars, knownVars,  allVars, diffVars, _) equation
      dxlist = createDiffListMeta(e,xlist,diffCref, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;
      
    // dummy diff
    case(e as DAE.CREF(componentRef=cref),xlist, functions, inputVars, paramVars, stateVars, knownVars,  allVars, diffVars, _) equation
      dxlist = createDiffListMeta(e,xlist,diffCref, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;

    // known vars
    case (DAE.CREF(componentRef=cref, ty=et), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
      ({(v1 as BackendDAE.VAR(bindExp=SOME(e1)))}, _) = BackendVariable.getVar(cref, knownVars);
      dxlist = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
    then dxlist;

    // diff crefVar
    case(e as DAE.CREF(componentRef=cref),xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, _) equation
      dxlist = createDiffListMeta(e,xlist,diffCrefVar, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;
    
    // binary
    case(DAE.BINARY(exp1=e1, operator=op, exp2=e2),xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, _) equation
      dxlist1 = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName);
      dxlist2 = differentiateWithRespectToXVec(e2, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName);
      dxlist = List.threadMap3(dxlist1,dxlist2,mergeBin,op,e1,e2);
    then dxlist;
    
    // uniary
    case(DAE.UNARY(operator=op, exp=e1), xlist, functions, inputVars, paramVars, stateVars, knownVars,  allVars, diffVars, _) equation
      dxlist1 = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars,  allVars, diffVars, inMatrixName);
      dxlist = List.map1(dxlist1,mergeUn,op);
    then dxlist;

    // der(x)
    case (e as DAE.CALL(path=fname, expLst={e1}), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, _)
      equation
      Builtin.isDer(fname);
      dxlist = createDiffListMeta(e,xlist,diffDerCref, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars,  diffVars, inMatrixName)));
    then dxlist;

    // function call
    case (e as DAE.CALL(path=_, expLst={e1}), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        dxlist1 = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        dxlist = List.map2(dxlist1,mergeCall,e1,e);
    then dxlist;

    // function call more than one argument
    case (e as DAE.CALL(path=_, expLst=expList1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        expListLst = List.map9( expList1, differentiateWithRespectToXVec, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        expListLst = List.transposeList(expListLst);
        dxlist = List.map1(expListLst,mergeCallExpList,e);
    then dxlist;      
      
    // extern functions (analytical and numeric)
    case (e as DAE.CALL(path=fname, expLst=expList1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
       dxlist = createDiffListMeta(e,xlist,diffNumCall, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName)));
    then dxlist;
    
    // cast
    case (DAE.CAST(ty=et, exp=e1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _) equation
      dxlist1 = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      dxlist = List.map1(dxlist1,mergeCast,et);
    then dxlist;

    // relations
    case (e as DAE.RELATION(e1, op, e2, index, optionExpisASUB), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _) equation
        dxlist = createDiffListMeta(e,xlist,diffRealZero, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName)));
    then dxlist;

      // differentiate if-expressions
    case (DAE.IFEXP(expCond=e, expThen=e1, expElse=e2), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
      dxlist1 = differentiateWithRespectToXVec(e1, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      dxlist2 = differentiateWithRespectToXVec(e2, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
      dxlist = List.threadMap1(dxlist1,dxlist2,mergeIf,e);
    then dxlist;

      
    case (e as DAE.ARRAY(ty = et,scalar = b,array = expList1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        expListLst = List.map9(expList1, differentiateWithRespectToXVec, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        expListLst = List.transposeList(expListLst);
        dxlist = List.map2(expListLst, mergeArray, et, b);
      then
        dxlist;
    
    case (DAE.TUPLE(PR = expList1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars,diffVars, _)
      equation
        expListLst = List.map9(expList1, differentiateWithRespectToXVec, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        expListLst = List.transposeList(expListLst);
        dxlist = List.map(expListLst, mergeTuple);
      then
        dxlist;
    
    case (DAE.ASUB(exp = e,sub = expList1), xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, _)
      equation
        dxlist = differentiateWithRespectToXVec(e, xlist, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        dxlist = List.map1(dxlist,Expression.makeASUB, expList1);
      then
       dxlist;
           
    case(e, xlist, _, _, _, _, _, _,_, _)
      equation
        true = Flags.isSet(Flags.FAILTRACE_JAC);
        str = "BackendDAEOptimize.differentiateWithRespectToXVec failed: " +& ExpressionDump.printExpStr(e) +& "\n";
        print(str);
        //Error.addMessage(Error.INTERNAL_ERROR, {str});
      then {};
  end matchcontinue;
end differentiateWithRespectToXVec;

protected function createDiffListMeta
  input DAE.Exp inExp;
  input list<DAE.ComponentRef> indiffVars;
  input FuncExpType func;
  input Option<Type_a> inTypeA;
  output list<DAE.Exp> outExpList;
  partial function FuncExpType
    input tuple<DAE.Exp, DAE.ComponentRef, Option<Type_a>> inTplExpTypeA;
    output DAE.Exp outTplExpTypeA;
    replaceable type Type_a subtypeof Any;
  end FuncExpType;
  replaceable type Type_a subtypeof Any;
algorithm 
   outExpList := matchcontinue (inExp, indiffVars, func, inTypeA)  
   local
     DAE.Exp e,e1;
     DAE.ComponentRef diff_cref;
     list<DAE.ComponentRef> rest;
     list<DAE.Exp> res;
     Option<Type_a> typea;
     String str;
    
     case(e, {}, _, _) then {};
     
     case(e, diff_cref::rest, _, typea)
       equation
         e1 = func((e, diff_cref, typea));
         res = createDiffListMeta(e,rest,func,typea);
       then e1::res;

     case(e, diff_cref::rest, _, _)
       equation
        true = Flags.isSet(Flags.FAILTRACE_JAC);
         str = "BackendDAEOptimize.createDiffListMeta failed: " +& ExpressionDump.printExpStr(e) +& " | " +& ComponentReference.printComponentRefStr(diff_cref) +& "\n";
         print(str);
        //Error.addMessage(Error.INTERNAL_ERROR, {str});
       then fail();
  end matchcontinue;
end createDiffListMeta;




/*
 * diff functions for differemtiatewrtX vectorize
 *
 */
protected function diffInt
  input tuple<DAE.Exp, DAE.ComponentRef, Option<Type_a>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
  replaceable type Type_a subtypeof Any;
algorithm
  outTplExpTypeA := match(inTplExpTypeA)
    case(_) then DAE.ICONST(0);
 end match;
end diffInt;

protected function diffRealZero
  input tuple<DAE.Exp, DAE.ComponentRef, Option<Type_a>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
  replaceable type Type_a subtypeof Any;
algorithm
  outTplExpTypeA := match(inTplExpTypeA)
    case(_) then DAE.RCONST(0.0);
 end match;
end diffRealZero;

protected function diffCrefVar
  input tuple<DAE.Exp, DAE.ComponentRef, Option<tuple<DAE.FunctionTree,BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, list<DAE.ComponentRef>, tuple<String,Boolean>>>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
  replaceable type Type_a subtypeof Any;
algorithm
  outTplExpTypeA := match(inTplExpTypeA)
  local
    DAE.ComponentRef cref,cref_,x;
    DAE.Type et;
    tuple<String,Boolean> matrixName;
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, _, _, _, _, matrixName))))
      equation
      cref_ = differentiateVarWithRespectToX(cref, x, matrixName);
      //print(" *** diffCrefVar : " +& ComponentReference.printComponentRefStr(cref) +& " w.r.t " +& ComponentReference.printComponentRefStr(x) +& "\n");
    then DAE.CREF(cref_, et);
 end match;
end diffCrefVar;

protected function diffCref
  input tuple<DAE.Exp, DAE.ComponentRef, Option<tuple<DAE.FunctionTree,BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, list<DAE.ComponentRef>, tuple<String,Boolean>>>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
algorithm
  outTplExpTypeA := matchcontinue(inTplExpTypeA)
  local
    DAE.Type et;
    DAE.ComponentRef x, cref,cref_;
    list<DAE.ComponentRef> diffVars;
    DAE.Exp e1;
    BackendDAE.Variables inputVars, paramVars, stateVars, allVars;
    BackendDAE.Var v1;
    list<Boolean> b_lst;
    String matrixName;
    
    // d(discrete)/d(x) = 0
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, _, _, allVars, _, _))))
      equation
      ({v1 as BackendDAE.VAR(varKind = BackendDAE.DISCRETE())}, _) = BackendVariable.getVar(cref, allVars);
    then DAE.RCONST(0.0);    

    //tearing
    // d(x)/d(x)
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, _, _, _, _, (_,true)))))
      equation
        true = ComponentReference.crefEqualNoStringCompare(cref, x);
        e1 = Expression.makeConstOne(et);
      then
        e1;
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, _, _, _, diffVars, (_,true)))))
      equation
      b_lst = List.map1(diffVars,ComponentReference.crefEqual,cref);
      true = Util.boolOrList(b_lst);
      (e1,_) = Expression.makeZeroExpression(Expression.arrayDimension(et));
    then
      e1;
            
    // d(x)/d(x)
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, _, _, _, diffVars, (matrixName,false)))))
      equation
      b_lst = List.map1(diffVars,ComponentReference.crefEqual,cref);
      true = Util.boolOrList(b_lst);
      cref_ = differentiateVarWithRespectToX(cref, cref, (matrixName,false));
      //print(" *** diffCref : " +& ComponentReference.printComponentRefStr(cref) +& " w.r.t " +& ComponentReference.printComponentRefStr(x) +& "\n");
    then
      DAE.CREF(cref_, et);
    
    // d(state)/d(x) = 0
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, _, stateVars, _, _, _, _))))
      equation
      ({v1}, _) = BackendVariable.getVar(cref, stateVars);
    then DAE.RCONST(0.0);

    // d(input)/d(x) = 0
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, inputVars, _, _, _, _, _, _))))
      equation
      ({v1}, _) = BackendVariable.getVar(cref, inputVars);
    then DAE.RCONST(0.0);

    // d(parameter)/d(x) = 0
    case((DAE.CREF(componentRef=cref, ty=et),x,SOME((_, _, paramVars, _, _, _, _, _))))
      equation
      ({v1}, _) = BackendVariable.getVar(cref, paramVars);
    then DAE.RCONST(0.0);
      
 end matchcontinue;
end diffCref;

protected function diffDerCref
  input tuple<DAE.Exp, DAE.ComponentRef, Option<tuple<DAE.FunctionTree,BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, list<DAE.ComponentRef>, tuple<String,Boolean>>>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
  replaceable type Type_a subtypeof Any;
algorithm
  outTplExpTypeA := matchcontinue(inTplExpTypeA)
  local
    Absyn.Path fname;
    DAE.Exp e1;
    DAE.ComponentRef x,cref;
    tuple<String,Boolean> matrixName;
    Option<tuple<DAE.FunctionTree,BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, list<DAE.ComponentRef>, tuple<String,Boolean>>> tpl;
    
    case((DAE.CALL(path=fname, expLst={e1}),x,tpl as SOME((_, _, _, _, _, _, _, matrixName as (_,true)))))
      equation
        e1 = diffCref((e1,x,tpl));
    then e1; 
    
    case((DAE.CALL(path=fname, expLst={e1}),x,SOME((_, _, _, _, _, _, _, matrixName))))
      equation
      cref = Expression.expCref(e1);
      cref = ComponentReference.crefPrefixDer(cref);
      //x = DAE.CREF_IDENT("pDERdummy",DAE.T_REAL_DEFAULT,{});
      cref = differentiateVarWithRespectToX(cref, x, matrixName);
    then DAE.CREF(cref, DAE.T_REAL_DEFAULT);
 end matchcontinue;
end diffDerCref;

protected function diffNumCall
  input tuple<DAE.Exp, DAE.ComponentRef, Option<tuple<DAE.FunctionTree, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, BackendDAE.Variables, list<DAE.ComponentRef>, tuple<String,Boolean>>>> inTplExpTypeA;
  output DAE.Exp outTplExpTypeA;
algorithm
  outTplExpTypeA := matchcontinue(inTplExpTypeA)
  local
    Absyn.Path fname,derFname;
    DAE.ComponentRef x;
    DAE.Exp e,e1;
    list<DAE.Exp> expList1,expList2;
    DAE.Type tp;
    Integer nArgs;
    BackendDAE.Variables inputVars, paramVars, stateVars, knownVars, allVars;
    list<DAE.ComponentRef> diffVars;
    DAE.FunctionTree functions;
    list<tuple<Integer,DAE.derivativeCond>> conditions;
    tuple<String,Boolean> inMatrixName;
    //Option<tuple<DAE.FunctionTree, list<BackendDAE.Var>, list<BackendDAE.Var>, list<BackendDAE.Var>, list<BackendDAE.Var>, list<BackendDAE.Var>>> inTpl;
    // extern functions (analytical)
    case ((e as DAE.CALL(path=fname, expLst=expList1), x, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName))))
      equation
        nArgs = listLength(expList1);
        (DAE.FUNCTION_DER_MAPPER(derivativeFunction=derFname,conditionRefs=conditions), tp) = Derive.getFunctionMapper(fname, functions);
        expList2 = deriveExpListwrtstate(expList1, nArgs, conditions, x, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        e1 = partialAnalyticalDifferentiation(expList1, expList2, e, derFname, listLength(expList2));
        (e1,_) = ExpressionSimplify.simplify(e1);
      then e1;
    case ((e as DAE.CALL(path=fname, expLst=expList1), x, SOME((functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName))))
      equation
        //(SOME((functions, inputVars, paramVars, stateVars, knownVars, diffVars))) = inTpl;
        Debug.fcall(Flags.JAC_DUMP,print,"differentiate function call " +& Absyn.pathString(fname) +& "(" +& ExpressionDump.printExpListStr(expList1) +& ") numerical.\n");
        nArgs = listLength(expList1);
        expList2 = deriveExpListwrtstate2(expList1, nArgs, x, functions, inputVars, paramVars, stateVars, knownVars, allVars, diffVars, inMatrixName);
        Debug.fcall(Flags.JAC_DUMP,print,"derived ExpList args: (" +& ExpressionDump.printExpListStr(expList2) +& "\n");
        e1 = partialNumericalDifferentiation(expList1, expList2, x, e);
        Debug.fcall(Flags.JAC_DUMP,print,"derived exp : (" +& ExpressionDump.printExpStr(e1) +& "\n");
        (e1,_) = ExpressionSimplify.simplify(e1);
        Debug.fcall(Flags.JAC_DUMP,print,"derived exp simplify: (" +& ExpressionDump.printExpStr(e1) +& "\n");
      then e1;
 end matchcontinue;
end diffNumCall;




/*
 * Merge functions for differemtiatewrtX vectorize
 *
 */
protected function mergeCall
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.Exp inOrgExp1;
  output DAE.Exp outExp;
algorithm
  outExp := match(inExp1,inExp2,inOrgExp1)
  local
    DAE.Exp e;
    //sin(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("sin")))
      equation
        e = DAE.BINARY(inExp1, DAE.MUL(DAE.T_REAL_DEFAULT), DAE.CALL(Absyn.IDENT("cos"),{inExp2},DAE.callAttrBuiltinReal));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    // cos(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("cos")))
      equation
        e = DAE.UNARY(DAE.UMINUS(DAE.T_REAL_DEFAULT), DAE.BINARY(inExp1,DAE.MUL(DAE.T_REAL_DEFAULT), DAE.CALL(Absyn.IDENT("sin"),{inExp2},DAE.callAttrBuiltinReal)));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    // ln(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("log")))
      equation
        e = DAE.BINARY(inExp1, DAE.DIV(DAE.T_REAL_DEFAULT), inExp2);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    // log10(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("log10")))
      equation
        e = DAE.BINARY(inExp1, DAE.DIV(DAE.T_REAL_DEFAULT), DAE.BINARY(inExp2, DAE.MUL(DAE.T_REAL_DEFAULT), DAE.CALL(Absyn.IDENT("log"),{DAE.RCONST(10.0)},DAE.callAttrBuiltinReal)));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    // exp(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("exp")))
      equation
        e = DAE.BINARY(inExp1,DAE.MUL(DAE.T_REAL_DEFAULT), DAE.CALL(Absyn.IDENT("exp"),{inExp2},DAE.callAttrBuiltinReal));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    // sqrt(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("sqrt")))
      equation
        e = DAE.BINARY(
          DAE.BINARY(DAE.RCONST(1.0),DAE.DIV(DAE.T_REAL_DEFAULT),
          DAE.BINARY(DAE.RCONST(2.0),DAE.MUL(DAE.T_REAL_DEFAULT),
          DAE.CALL(Absyn.IDENT("sqrt"),{inExp2},DAE.callAttrBuiltinReal))),DAE.MUL(DAE.T_REAL_DEFAULT),inExp1);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
   // abs(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("abs")))
      equation
        e = DAE.IFEXP(DAE.RELATION(inExp2,DAE.GREATEREQ(DAE.T_REAL_DEFAULT),DAE.RCONST(0.0),-1,NONE()), inExp1, DAE.UNARY(DAE.UMINUS(DAE.T_REAL_DEFAULT),inExp1));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;

    // openmodelica build call $_start(x)
    case (_,_,DAE.CALL(path=Absyn.IDENT("$_start")))
      equation
        e = DAE.RCONST(0.0);
      then e;
  end match;
end mergeCall;


protected function mergeCallExpList
  input list<DAE.Exp> inExp1Lst;
  input DAE.Exp inOrgExp1;
  output DAE.Exp outExp;
algorithm
  outExp := match(inExp1Lst,inOrgExp1)
  local
    DAE.Exp e,z1,z2;
    DAE.Exp dz1,dz2;
    //max(x,y)
    case ({dz1,dz2},DAE.CALL(path=Absyn.IDENT("max"),expLst={z1,z2}))
      equation
        e = DAE.IFEXP(DAE.RELATION(z1, DAE.GREATER(DAE.T_REAL_DEFAULT), z2, -1, NONE()),
                      dz1, dz2);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
  end match;
end mergeCallExpList;

protected function mergeBin
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.Operator inOp;
  input DAE.Exp inOrgExp1;
  input DAE.Exp inOrgExp2;
  output DAE.Exp outExp;
algorithm
  outExp := matchcontinue(inExp1,inExp2,inOp,inOrgExp1,inOrgExp2)
  local
    DAE.Exp e,z1,z2;
    DAE.Type et;
    case (_,_,DAE.ADD(_), _, _)
      equation
        e = DAE.BINARY(inExp1,inOp,inExp2);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    case (_,_,DAE.SUB(_), _, _)
      equation
        e = DAE.BINARY(inExp1,inOp,inExp2);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    case (_,_,DAE.MUL(et),_,_)
      equation
        e = DAE.BINARY(DAE.BINARY(inExp1, DAE.MUL(et), inOrgExp2), DAE.ADD(et), DAE.BINARY(inOrgExp1, DAE.MUL(et), inExp2));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    case (_,_,DAE.MUL_ARRAY_SCALAR(et),_,_)
      equation
        e = DAE.BINARY(DAE.BINARY(inExp1, DAE.MUL_ARRAY_SCALAR(et), inOrgExp2), DAE.ADD_ARR(et), DAE.BINARY(inOrgExp1, DAE.MUL_ARRAY_SCALAR(et), inExp2));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;        
    case (_,_,DAE.DIV(et),_,_)
      equation
        e = DAE.BINARY(DAE.BINARY(DAE.BINARY(inExp1, DAE.MUL(et), inOrgExp2), DAE.SUB(et), DAE.BINARY(inOrgExp1, DAE.MUL(et), inExp2)), DAE.DIV(et), DAE.BINARY(inOrgExp2, DAE.MUL(et), inOrgExp2));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    case (_,_,DAE.POW(et),_,_)
      equation
        true = Expression.isConst(inOrgExp2);
        e = DAE.BINARY(inExp1, DAE.MUL(et), DAE.BINARY(inOrgExp2, DAE.MUL(et), DAE.BINARY(inOrgExp1, DAE.POW(et), DAE.BINARY(inOrgExp2, DAE.SUB(et), DAE.RCONST(1.0)))));
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
    case (_,_,DAE.POW(et),_,_)
      equation
        z1 = DAE.BINARY(inExp1, DAE.DIV(et), inOrgExp1);
        z1 = DAE.BINARY(inOrgExp2, DAE.MUL(et), z1);
        z2 = DAE.CALL(Absyn.IDENT("log"), {inOrgExp1}, DAE.callAttrBuiltinReal);
        z2 = DAE.BINARY(inExp2, DAE.MUL(et), z2);
        z1 = DAE.BINARY(z1, DAE.ADD(et), z2);
        z2 = DAE.BINARY(inOrgExp1, DAE.POW(et), inOrgExp2);
        z1 = DAE.BINARY(z1, DAE.MUL(et), z2);
        (e,_) = ExpressionSimplify.simplify(z1);
      then e;
 end matchcontinue;
end mergeBin;

protected function mergeIf
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.Exp inOrgExp1;
  output DAE.Exp outExp;
algorithm
  outExp := match(inExp1,inExp2,inOrgExp1)
    case (_,_,_) then DAE.IFEXP(inOrgExp1, inExp1, inExp2);
 end match;
end mergeIf;

protected function mergeUn
  input DAE.Exp inExp1;
  input DAE.Operator inOp;
  output DAE.Exp outExp;
algorithm
  outExp := match(inExp1,inOp)
  local
    DAE.Exp e;
    case (_,_)
      equation
        e = DAE.UNARY(inOp,inExp1);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
 end match;
end mergeUn;

protected function mergeCast
  input DAE.Exp inExp1;
  input DAE.Type inType;
  output DAE.Exp outExp;
algorithm
  outExp := match(inExp1,inType)
  local
    DAE.Exp e;
    case (_,_)
      equation
        e = DAE.CAST(inType,inExp1);
        (e,_) = ExpressionSimplify.simplify(e);
      then e;
 end match;
end mergeCast;

protected function mergeRelation
  input DAE.Exp inExp0;
  input DAE.Exp inExp1;
  input DAE.Exp inExp2;
  input DAE.Operator inOp;
  input Integer inIndex;
  input Option<tuple<DAE.Exp,Integer,Integer>> inOptionExpisASUB;
  output DAE.Exp outExp;
algorithm
  outExp := matchcontinue(inExp0,inExp1,inExp2,inOp, inIndex, inOptionExpisASUB)
  local
    DAE.Exp e;
    case (inExp0,inExp1,inExp2,inOp,inIndex,inOptionExpisASUB)
      equation
        e = DAE.RELATION(inExp1,inOp,inExp2,inIndex,inOptionExpisASUB);
    then e;
 end matchcontinue;
end mergeRelation;

protected function mergeArray
  input list<DAE.Exp> inExplst;
  input DAE.Type inType;
  input Boolean inScalar;
  output DAE.Exp outExp;
algorithm
  outExp :=  DAE.ARRAY(inType, inScalar, inExplst);
end mergeArray;

protected function mergeTuple
  input list<DAE.Exp> inExplst;
  output DAE.Exp outExp;
algorithm
  outExp :=  DAE.TUPLE(inExplst);
end mergeTuple;




/*
 * parallel backend stuff
 *
 */
public function collapseIndependentBlocks
  "Finds independent partitions of the equation system by "
  input BackendDAE.BackendDAE dlow;
  output BackendDAE.BackendDAE outDlow;
algorithm
  outDlow := match (dlow)
    local
      BackendDAE.EqSystem syst;
      list<BackendDAE.EqSystem> systs;
      BackendDAE.Shared shared;
    case (BackendDAE.DAE(systs,shared))
      equation
        // We can use listReduce as if there is no eq-system something went terribly wrong
        syst = List.reduce(systs,mergeIndependentBlocks);
      then BackendDAE.DAE({syst},shared);
  end match;
end collapseIndependentBlocks;

protected function mergeIndependentBlocks
  input BackendDAE.EqSystem syst1;
  input BackendDAE.EqSystem syst2;
  output BackendDAE.EqSystem syst;
protected
  BackendDAE.Variables vars,vars1,vars2;
  BackendDAE.EquationArray eqs,eqs1,eqs2;
  BackendDAE.StateSets stateSets,statSets1;
algorithm
  BackendDAE.EQSYSTEM(orderedVars=vars1,orderedEqs=eqs1,stateSets=stateSets) := syst1;
  BackendDAE.EQSYSTEM(orderedVars=vars2,orderedEqs=eqs2,stateSets=statSets1) := syst2;
  vars := BackendVariable.addVars(BackendVariable.varList(vars2),vars1);
  eqs := BackendEquation.addEquations(BackendEquation.equationList(eqs2),eqs1);
  stateSets := listAppend(stateSets,statSets1);
  syst := BackendDAE.EQSYSTEM(vars,eqs,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);
end mergeIndependentBlocks;

public function partitionIndependentBlocks
  "Finds independent partitions of the equation system by "
  input BackendDAE.BackendDAE dlow;
  output BackendDAE.BackendDAE outDlow;
algorithm
  outDlow := match (dlow)
    local
      BackendDAE.EqSystem syst;
      list<BackendDAE.EqSystem> systs;
      BackendDAE.Shared shared;
    case (BackendDAE.DAE({syst},shared))
      equation
        (systs,shared) = partitionIndependentBlocksHelper(syst,shared,Error.getNumErrorMessages());
      then BackendDAE.DAE(systs,shared); // TODO: Add support for partitioned systems of equations
  end match;
end partitionIndependentBlocks;

protected function partitionIndependentBlocksHelper
  "Finds independent partitions of the equation system by "
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input Integer numErrorMessages;
  output list<BackendDAE.EqSystem> systs;
  output BackendDAE.Shared oshared;
algorithm
  (systs,oshared) := matchcontinue (isyst,ishared,numErrorMessages)
    local
      BackendDAE.IncidenceMatrix m,mT;
      array<Integer> ixs;
      Boolean b;
      Integer i;
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;
      
    case (syst,shared,_)
      equation
        // print("partitionIndependentBlocks: TODO: Implement me\n");
        (syst,m,mT) = BackendDAEUtil.getIncidenceMatrixfromOption(syst,BackendDAE.NORMAL());
        ixs = arrayCreate(arrayLength(m),0);
        // ixsT = arrayCreate(arrayLength(mT),0);
        i = partitionIndependentBlocks0(arrayLength(m),0,mT,m,ixs);
        // i2 = partitionIndependentBlocks0(arrayLength(mT),0,mT,m,ixsT);
        b = i > 1;
        // Debug.bcall(b,BackendDump.dump,BackendDAE.DAE({syst},shared));
        // printPartition(b,ixs);
        systs = Debug.bcallret4(b,partitionIndependentBlocksSplitBlocks,i,syst,ixs,mT,{syst});
      then (systs,shared);
    else
      equation
        Error.assertion(not (numErrorMessages==Error.getNumErrorMessages()),"BackendDAEOptimize.partitionIndependentBlocks failed without good error message",Absyn.dummyInfo);
      then fail();
  end matchcontinue;
end partitionIndependentBlocksHelper;

protected function partitionIndependentBlocksSplitBlocks
  "Partitions the independent blocks into list<array<...>> by first constructing an array<list<...>> structure for the algorithm complexity"
  input Integer n;
  input BackendDAE.EqSystem syst;
  input array<Integer> ixs;
  input BackendDAE.IncidenceMatrix mT;
  output list<BackendDAE.EqSystem> systs;
algorithm
  systs := match (n,syst,ixs,mT)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray arr;
      array<list<BackendDAE.Equation>> ea;
      array<list<BackendDAE.Var>> va;
      list<list<BackendDAE.Equation>> el;
      list<list<BackendDAE.Var>> vl;
      Integer i1,i2;
      String s1,s2;
    case (_,BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=arr),_,_)
      equation
        ea = arrayCreate(n,{});
        va = arrayCreate(n,{});
        i1 = BackendDAEUtil.equationSize(arr);
        i2 = BackendVariable.numVariables(vars);
        s1 = intString(i1);
        s2 = intString(i2);
        Error.assertionOrAddSourceMessage(i1 == i2,
          Util.if_(i1 > i2, Error.OVERDET_EQN_SYSTEM, Error.UNDERDET_EQN_SYSTEM), 
          {s1,s2}, Absyn.dummyInfo);

        partitionEquations(BackendDAEUtil.equationArraySize(arr),arr,ixs,ea);
        partitionVars(i2,arr,vars,ixs,mT,va);
        el = arrayList(ea);
        vl = arrayList(va);
        (systs,true) = List.threadMapFold(el,vl,createEqSystem,true);
      then systs;
  end match;
end partitionIndependentBlocksSplitBlocks;

protected function createEqSystem
  input list<BackendDAE.Equation> el;
  input list<BackendDAE.Var> vl;
  input Boolean success;
  output BackendDAE.EqSystem syst;
  output Boolean osuccess;
protected
  BackendDAE.EquationArray arr;
  BackendDAE.Variables vars;
  Integer i1,i2;
  String s1,s2,s3,s4;
  list<String> crs;
algorithm
  vars := BackendVariable.listVar1(vl);
  arr := BackendEquation.listEquation(el);
  i1 := BackendDAEUtil.equationSize(arr);
  i2 := BackendVariable.numVariables(vars);
  s1 := intString(i1);
  s2 := intString(i2);
  crs := Debug.bcallret3(i1<>i2,List.mapMap,vl,BackendVariable.varCref,ComponentReference.printComponentRefStr,{});
  s3 := stringDelimitList(crs,"\n");
  s4 := Debug.bcallret1(i1<>i2,BackendDump.dumpEqnsStr,el,"");
  // Can this even be triggered? We check that all variables are defined somewhere, so everything should be balanced already?
  Debug.bcall3(i1<>i2,Error.addSourceMessage,Error.IMBALANCED_EQUATIONS,{s1,s2,s3,s4},Absyn.dummyInfo);
  syst := BackendDAE.EQSYSTEM(vars,arr,NONE(),NONE(),BackendDAE.NO_MATCHING(),{});
  osuccess := success and i1==i2;
end createEqSystem;

protected function partitionEquations
  input Integer n;
  input BackendDAE.EquationArray arr;
  input array<Integer> ixs;
  input array<list<BackendDAE.Equation>> ea;
algorithm
  _ := match (n,arr,ixs,ea)
    local
      Integer ix;
      list<BackendDAE.Equation> lst;
      BackendDAE.Equation eq;
    case (0,_,_,_) then ();
    case (_,_,_,_)
      equation
        ix = ixs[n];
        lst = ea[ix];
        eq = BackendDAEUtil.equationNth(arr,n-1);
        lst = eq::lst;
        // print("adding eq " +& intString(n) +& " to group " +& intString(ix) +& "\n");
        _ = arrayUpdate(ea,ix,lst);
        partitionEquations(n-1,arr,ixs,ea);
      then ();
  end match;
end partitionEquations;

protected function partitionVars
  input Integer n;
  input BackendDAE.EquationArray arr;
  input BackendDAE.Variables vars;
  input array<Integer> ixs;
  input BackendDAE.IncidenceMatrix mT;
  input array<list<BackendDAE.Var>> va;
algorithm
  _ := match (n,arr,vars,ixs,mT,va)
    local
      Integer ix,eqix;
      list<BackendDAE.Var> lst;
      BackendDAE.Var v;
      Boolean b;
      DAE.ComponentRef cr;
      String name;
      Absyn.Info info;
    case (0,_,_,_,_,_) then ();
    case (_,_,_,_,_,_)
      equation
        v = BackendVariable.getVarAt(vars,n);
        cr = BackendVariable.varCref(v);
        // Select any equation that could define this variable
        b = not List.isEmpty(mT[n]);
        name = Debug.bcallret1(not b,ComponentReference.printComponentRefStr,cr,"");
        info = DAEUtil.getElementSourceFileInfo(BackendVariable.getVarSource(v));
        Error.assertionOrAddSourceMessage(b,Error.EQUATIONS_VAR_NOT_DEFINED,{name},info);
        // print("adding var " +& intString(n) +& " to group ???\n");
        eqix::_ = mT[n];
        eqix = intAbs(eqix);
        // print("var " +& intString(n) +& " has eq " +& intString(eqix) +& "\n");
        // That's the index of the indep.system
        ix = ixs[eqix];
        lst = va[ix];
        lst = v::lst;
        // print("adding var " +& intString(n) +& " to group " +& intString(ix) +& " (comes from eq: "+& intString(eqix) +&")\n");
        _ = arrayUpdate(va,ix,lst);
        partitionVars(n-1,arr,vars,ixs,mT,va);
      then ();
  end match;
end partitionVars;

protected function partitionIndependentBlocks0
  input Integer n;
  input Integer n2;
  input BackendDAE.IncidenceMatrix m;
  input BackendDAE.IncidenceMatrixT mT;
  input array<Integer> ixs;
  output Integer on;
algorithm
  on := match (n,n2,m,mT,ixs)
    local
      Boolean b;
    case (0,_,_,_,_) then n2;
    case (_,_,_,_,_)
      equation
        b = partitionIndependentBlocks1(n,n2+1,m,mT,ixs);
      then partitionIndependentBlocks0(n-1,Util.if_(b,n2+1,n2),m,mT,ixs);
  end match;
end partitionIndependentBlocks0;

protected function partitionIndependentBlocks1
  input Integer ix;
  input Integer n;
  input BackendDAE.IncidenceMatrix m;
  input BackendDAE.IncidenceMatrixT mT;
  input array<Integer> ixs;
  output Boolean ochange;
algorithm
  ochange := partitionIndependentBlocks2(ixs[ix] == 0,ix,n,m,mT,ixs);
end partitionIndependentBlocks1;

protected function partitionIndependentBlocks2
  input Boolean b;
  input Integer ix;
  input Integer n;
  input BackendDAE.IncidenceMatrix m;
  input BackendDAE.IncidenceMatrixT mT;
  input array<Integer> inIxs;
  output Boolean change;
algorithm
  change := match (b,ix,n,m,mT,inIxs)
    local
      list<Integer> lst;
      list<list<Integer>> lsts;
      array<Integer> ixs;
      
    case (false,_,_,_,_,_) then false;
    case (true,_,_,_,_,ixs)
      equation
        // i = ixs[ix];
        // print(intString(ix) +& "; update crap\n");
        // print("mark\n");
        ixs = arrayUpdate(ixs,ix,n);
        // print("mark OK\n");
        lst = List.map(mT[ix],intAbs);
        // print(stringDelimitList(List.map(lst,intString),",") +& "\n");
        // print("len:" +& intString(arrayLength(m)) +& "\n");
        lsts = List.map1r(lst,arrayGet,m);
        // print("arrayNth OK\n");
        lst = List.map(List.flatten(lsts),intAbs);
        // print(stringDelimitList(List.map(lst,intString),",") +& "\n");
        // print("lst get\n");
        _ = List.map4(lst,partitionIndependentBlocks1,n,m,mT,ixs);
      then true;
  end match;
end partitionIndependentBlocks2;

protected function arrayUpdateForPartition
  input Integer ix;
  input array<Integer> ixs;
  input Integer val;
  output array<Integer> oixs;
algorithm
  // print("arrayUpdate("+&intString(ix+1)+&","+&intString(val)+&")\n");
  oixs := arrayUpdate(ixs,ix+1,val);
end arrayUpdateForPartition;

protected function printPartition
  input Boolean b;
  input array<Integer> ixs;
algorithm
  _ := match (b,ixs)
    case (true,ixs)
      equation
        print("Got partition!\n");
        print(stringDelimitList(List.map(arrayList(ixs), intString), ","));
        print("\n");
      then ();
    else ();
  end match;
end printPartition;

public function residualForm
  "Puts equations like x=y in the form of 0=x-y"
  input BackendDAE.BackendDAE dlow;
  output BackendDAE.BackendDAE odlow;
algorithm
  odlow := BackendDAEUtil.mapEqSystem1(dlow,residualForm1,1);
end residualForm;

protected function residualForm1
  "Puts equations like x=y in the form of 0=x-y"
  input BackendDAE.EqSystem syst;
  input Integer i;
  input BackendDAE.Shared shared;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
protected
  BackendDAE.EquationArray eqs;
algorithm
  BackendDAE.EQSYSTEM(orderedEqs=eqs) := syst;
  (_,_) := BackendEquation.traverseBackendDAEEqnsWithUpdate(eqs, residualForm2, 1);
  osyst := syst;
  oshared := shared;
end residualForm1;

protected function residualForm2
  input tuple<BackendDAE.Equation,Integer> tpl;
  output tuple<BackendDAE.Equation,Integer> otpl;
algorithm
  otpl := matchcontinue tpl
    local
      tuple<BackendDAE.Equation,Integer> ntpl;
      DAE.Exp e1,e2,e;
      DAE.ElementSource source;
      Integer i;
      Boolean diffed;
    case ((BackendDAE.EQUATION(e1,e2,source,diffed),i))
      equation
        // This is ok, because EQUATION is not an array equation :D
        DAE.T_REAL(source = _) = Expression.typeof(e1);
        false = Expression.isZero(e1) or Expression.isZero(e2);
        e = DAE.BINARY(e1,DAE.SUB(DAE.T_REAL_DEFAULT),e2);
        (e,_) = ExpressionSimplify.simplify(e);
        source = DAEUtil.addSymbolicTransformation(source, DAE.OP_RESIDUAL(e1,e2,e));
        ntpl = (BackendDAE.EQUATION(DAE.RCONST(0.0),e,source,diffed),i);
      then ntpl;
    else tpl;
  end matchcontinue;
end residualForm2;




/*
 * simplify time independent function calls
 *
 */
public function simplifyTimeIndepFuncCalls "function simplifyTimeIndepFuncCalls
  simplifies time independent built in function calls like
  pre(param) -> param
  der(param) -> 0.0
  change(param) -> false
  edge(param) -> false
  author: Frenkel TUD 2012-06"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,simplifyTimeIndepFuncCalls0,false);
  outDAE := simplifyTimeIndepFuncCallsShared(outDAE);
end simplifyTimeIndepFuncCalls;

protected function simplifyTimeIndepFuncCalls0 "function simplifyTimeIndepFuncCalls0
  author: Frenkel TUD 2012-06"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) := 
    matchcontinue(isyst,sharedChanged)
    local
      BackendDAE.Variables orderedVars,knvars,aliasvars;
      BackendDAE.EquationArray orderedEqs;
      Option<BackendDAE.IncidenceMatrix> m;
      Option<BackendDAE.IncidenceMatrixT> mT;
      BackendDAE.Matching matching;
      BackendDAE.Shared shared;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared as BackendDAE.SHARED(knownVars = knvars,aliasVars = aliasvars), _))
      equation
        ((_,_,true)) = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(orderedEqs,traversersimplifyTimeIndepFuncCalls,(knvars,aliasvars,false));
      then
        (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared,true));
    else
      (isyst,sharedChanged);
  end matchcontinue;
end simplifyTimeIndepFuncCalls0;

protected function traversersimplifyTimeIndepFuncCalls "function traversersimplifyTimeIndepFuncCalls
  author: Frenkel TUD 2012-06"
  input tuple<DAE.Exp,tuple<BackendDAE.Variables,BackendDAE.Variables,Boolean>> itpl;
  output tuple<DAE.Exp,tuple<BackendDAE.Variables,BackendDAE.Variables,Boolean>> outTpl;
protected
  DAE.Exp e;
  tuple<BackendDAE.Variables,BackendDAE.Variables,Boolean> tpl;
algorithm
  (e,tpl) := itpl;
  outTpl := Expression.traverseExp(e,traverserExpsimplifyTimeIndepFuncCalls,tpl);
end traversersimplifyTimeIndepFuncCalls;

protected function traverserExpsimplifyTimeIndepFuncCalls "function traverserExpsimplifyTimeIndepFuncCalls
  author: Frenkel TUD 2012-06"
  input tuple<DAE.Exp,tuple<BackendDAE.Variables,BackendDAE.Variables,Boolean>> tpl;
  output tuple<DAE.Exp,tuple<BackendDAE.Variables,BackendDAE.Variables,Boolean>> outTpl;
algorithm
  outTpl := matchcontinue(tpl)
    local
      BackendDAE.Variables knvars,aliasvars;
      DAE.Type tp;
      DAE.Exp e,zero;
      DAE.ComponentRef cr;
      BackendDAE.Var var;
      DAE.CallAttributes attr;
      Boolean negate;
    case((e as DAE.CALL(path=Absyn.IDENT(name = "der"),expLst={DAE.CREF(componentRef=cr,ty=tp)}),(knvars,aliasvars,_)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, knvars);
        false = BackendVariable.isVarOnTopLevelAndInput(var);
        (zero,_) = Expression.makeZeroExpression(Expression.arrayDimension(tp));
      then 
        ((zero,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "pre"),expLst={e as DAE.CREF(componentRef=cr)}),(knvars,aliasvars,_)))
      equation
        (_::{},_) = BackendVariable.getVar(cr, knvars);
      then
        ((e,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "pre"),expLst={e as DAE.CREF(componentRef=DAE.CREF_IDENT(ident="time"))}),(knvars,aliasvars,_)))
      then
        ((e,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "pre"),expLst={e as DAE.UNARY(DAE.UMINUS(_),DAE.CREF(componentRef=DAE.CREF_IDENT(ident="time")))}),(knvars,aliasvars,_)))
      then
        ((e,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "pre"),expLst={DAE.CREF(componentRef=cr,ty=tp)},attr=attr),(knvars,aliasvars,_)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, aliasvars);
        (cr,negate) = BackendVariable.getAlias(var);
        e = DAE.CREF(cr,tp);
        e = Debug.bcallret1(negate,Expression.negate,e,e);
        (e,_) = ExpressionSimplify.simplify(DAE.CALL(Absyn.IDENT("pre"),{e},attr));
        ((e,_)) = Expression.traverseExp(e,traverserExpsimplifyTimeIndepFuncCalls,(knvars,aliasvars,false));
      then 
        ((e,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "change"),expLst={e as DAE.CREF(componentRef=cr,ty=tp)}),(knvars,aliasvars,_)))
      equation
        (_::_,_) = BackendVariable.getVar(cr, knvars);
        zero = Expression.arrayFill(Expression.arrayDimension(tp),DAE.BCONST(false));
      then 
        ((zero,(knvars,aliasvars,true)));
    case((e as DAE.CALL(path=Absyn.IDENT(name = "change"),expLst={DAE.CREF(componentRef=cr,ty=tp)}),(knvars,aliasvars,_)))
      equation
        (_::_,_) = BackendVariable.getVar(cr, aliasvars);
        zero = Expression.arrayFill(Expression.arrayDimension(tp),DAE.BCONST(false));
      then 
        ((zero,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "change"),expLst={e as DAE.CREF(componentRef=DAE.CREF_IDENT(ident="time"))}),(knvars,aliasvars,_)))
      then
        ((DAE.BCONST(false),(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "change"),expLst={DAE.CREF(componentRef=cr,ty=tp)},attr=attr),(knvars,aliasvars,_)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, aliasvars);
        (cr,negate) = BackendVariable.getAlias(var);
        e = DAE.CREF(cr,tp);
        e = Debug.bcallret1(negate,Expression.negate,e,e);
        (e,_) = ExpressionSimplify.simplify(DAE.CALL(Absyn.IDENT("change"),{e},attr));
        ((e,_)) = Expression.traverseExp(e,traverserExpsimplifyTimeIndepFuncCalls,(knvars,aliasvars,false));
      then 
        ((e,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "edge"),expLst={e as DAE.CREF(componentRef=cr,ty=tp)}),(knvars,aliasvars,_)))
      equation
        (_::{},_) = BackendVariable.getVar(cr, knvars);
        zero = Expression.arrayFill(Expression.arrayDimension(tp),DAE.BCONST(false));
      then
        ((zero,(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "edge"),expLst={e as DAE.CREF(componentRef=DAE.CREF_IDENT(ident="time"))}),(knvars,aliasvars,_)))
      then
        ((DAE.BCONST(false),(knvars,aliasvars,true)));
    case((DAE.CALL(path=Absyn.IDENT(name = "edge"),expLst={DAE.CREF(componentRef=cr,ty=tp)},attr=attr),(knvars,aliasvars,_)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, aliasvars);
        (cr,negate) = BackendVariable.getAlias(var);
        e = DAE.CREF(cr,tp);
        e = Debug.bcallret1(negate,Expression.negate,e,e); 
        (e,_) = ExpressionSimplify.simplify(DAE.CALL(Absyn.IDENT("edge"),{e},attr));       
        ((e,_)) = Expression.traverseExp(e,traverserExpsimplifyTimeIndepFuncCalls,(knvars,aliasvars,false));
      then 
        ((e,(knvars,aliasvars,true)));
    case _ then tpl;
  end matchcontinue;
end traverserExpsimplifyTimeIndepFuncCalls;

protected function simplifyTimeIndepFuncCallsShared "function simplifyTimeIndepFuncCallsShared
  simplifies time independent built in function calls like
  pre(param) -> param
  der(param) -> 0.0 
  change(param) -> false
  edge(param) -> false
  author: Frenkel TUD 2012-06"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE:= match (inDAE)
    local
      BackendDAE.Variables knvars,exobj,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcTree;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EventInfo eventInfo;
      BackendDAE.BackendDAEType btp; 
      BackendDAE.EqSystems systs;  
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,eventInfo,eoc,btp,symjacs)))
      equation
        _ = BackendDAEUtil.traverseBackendDAEExpsVarsWithUpdate(knvars,traversersimplifyTimeIndepFuncCalls,(knvars,aliasVars,false));
        _ = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(inieqns,traversersimplifyTimeIndepFuncCalls,(knvars,aliasVars,false));
        _ = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(remeqns,traversersimplifyTimeIndepFuncCalls,(knvars,aliasVars,false));
        (eventInfo,_) = traverseEventInfoExps(eventInfo,traversersimplifyTimeIndepFuncCalls,(knvars,aliasVars,false));
      then 
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,eventInfo,eoc,btp,symjacs));
  end match;
end simplifyTimeIndepFuncCallsShared;

protected function traverseEventInfoExps
  replaceable type Type_a = polymorphic<Any>;
  input BackendDAE.EventInfo iEventInfo;
  input FuncExpType func;
  input Type_a inTypeA;
  output BackendDAE.EventInfo oEventInfo;
  output Type_a outTypeA;
  partial function FuncExpType
    input tuple<DAE.Exp, Type_a> inTpl;
    output tuple<DAE.Exp, Type_a> outTpl;
  end FuncExpType;
protected
  list<BackendDAE.WhenClause> whenClauseLst;
  list<BackendDAE.ZeroCrossing> zeroCrossingLst,sampleLst,relationsLst;
  Integer relationsNumber,numberMathEvents;
algorithm
  BackendDAE.EVENT_INFO(whenClauseLst,zeroCrossingLst,sampleLst,relationsLst,relationsNumber,numberMathEvents) := iEventInfo;
  (whenClauseLst,outTypeA) := traverseWhenClauseExps(whenClauseLst,func,inTypeA,{});
  (zeroCrossingLst,outTypeA) := traverseZeroCrossingExps(zeroCrossingLst,func,outTypeA,{});
  (sampleLst,outTypeA) := traverseZeroCrossingExps(sampleLst,func,outTypeA,{});
  (relationsLst,outTypeA) := traverseZeroCrossingExps(relationsLst,func,outTypeA,{});
  oEventInfo := BackendDAE.EVENT_INFO(whenClauseLst,zeroCrossingLst,sampleLst,relationsLst,relationsNumber,numberMathEvents);
end traverseEventInfoExps;

protected function traverseWhenClauseExps
  replaceable type Type_a = polymorphic<Any>;
  input list<BackendDAE.WhenClause> iWhenClauses;
  input FuncExpType func;
  input Type_a inTypeA;
  input list<BackendDAE.WhenClause> iAcc;
  output list<BackendDAE.WhenClause> oWhenClauses;
  output Type_a outTypeA;
  partial function FuncExpType
    input tuple<DAE.Exp, Type_a> inTpl;
    output tuple<DAE.Exp, Type_a> outTpl;
  end FuncExpType;
algorithm
  (oWhenClauses,outTypeA) := match(iWhenClauses,func,inTypeA,iAcc)
    local
      list<BackendDAE.WhenClause> whenClause;
      DAE.Exp condition;
      list<BackendDAE.WhenOperator> reinitStmtLst;
      Option<Integer> elseClause;
      Type_a arg;
    case({},_,_,_) then (listReverse(iAcc),inTypeA);
    case(BackendDAE.WHEN_CLAUSE(condition,reinitStmtLst,elseClause)::whenClause,_,_,_)
      equation
        ((condition,arg)) = Expression.traverseExp(condition,func,inTypeA);
        (whenClause,arg) = traverseWhenClauseExps(whenClause,func,arg,BackendDAE.WHEN_CLAUSE(condition,reinitStmtLst,elseClause)::iAcc);
      then
        (whenClause,arg); 
  end match;
end traverseWhenClauseExps;

protected function traverseZeroCrossingExps
  replaceable type Type_a = polymorphic<Any>;
  input list<BackendDAE.ZeroCrossing> iZeroCrossing;
  input FuncExpType func;
  input Type_a inTypeA;
  input list<BackendDAE.ZeroCrossing> iAcc;
  output list<BackendDAE.ZeroCrossing> oZeroCrossing;
  output Type_a outTypeA;
  partial function FuncExpType
    input tuple<DAE.Exp, Type_a> inTpl;
    output tuple<DAE.Exp, Type_a> outTpl;
  end FuncExpType;
algorithm
  (oZeroCrossing,outTypeA) := match(iZeroCrossing,func,inTypeA,iAcc)
    local
      list<BackendDAE.ZeroCrossing> zeroCrossing;
      DAE.Exp relation_;
      list<Integer> occurEquLst,occurWhenLst;
      Type_a arg;
    case({},_,_,_) then (listReverse(iAcc),inTypeA);
    case(BackendDAE.ZERO_CROSSING(relation_,occurEquLst,occurWhenLst)::zeroCrossing,_,_,_)
      equation
        ((relation_,arg)) = Expression.traverseExp(relation_,func,inTypeA);
        (zeroCrossing,arg) = traverseZeroCrossingExps(zeroCrossing,func,arg,BackendDAE.ZERO_CROSSING(relation_,occurEquLst,occurWhenLst)::iAcc);
      then
        (zeroCrossing,arg); 
  end match;
end traverseZeroCrossingExps;

/*
 * tearing
 *
 */
public function tearingSystemNew "function tearingSystem
  author: Frenkel TUD 2012-05"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := matchcontinue(inDAE)
    case(_)
      equation 
        false = Flags.getConfigBool(Flags.NO_TEARING);
        (outDAE,_) = BackendDAEUtil.mapEqSystemAndFold(inDAE,tearingSystemNew0,false);
      then outDAE;
    case(_) then inDAE;
   end matchcontinue;
end tearingSystemNew;

protected function tearingSystemNew0 "function tearingSystem0
  author: Frenkel TUD 2012-05"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) := 
    match(isyst,sharedChanged)
    local
      BackendDAE.StrongComponents comps;
      Boolean b,b1,b2;
      BackendDAE.Shared shared;
      BackendDAE.EqSystem syst;
      array<Integer> ass1,ass2;
    case (syst as BackendDAE.EQSYSTEM(matching=BackendDAE.MATCHING(ass1=ass1,ass2=ass2,comps=comps)),(shared, b1))
      equation
        (comps,b2) = tearingSystemNew1(syst,shared,comps,false,{});
        syst = Debug.bcallret2(b2, BackendDAEUtil.setEqSystemMatching, syst,BackendDAE.MATCHING(ass1,ass2,comps), syst);
        b = b1 or b2;
      then
        (syst,(shared,b));
  end match;  
end tearingSystemNew0;

protected function tearingSystemNew1 "function tearingSystemNew1
  author: Frenkel TUD 2012-05"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input BackendDAE.StrongComponents inComps;
  input Boolean iRunMatching;
  input BackendDAE.StrongComponents iAcc;
  output BackendDAE.StrongComponents oComps;
  output Boolean outRunMatching;
algorithm
  (oComps,outRunMatching):=
  matchcontinue (isyst,ishared,inComps,iRunMatching,iAcc)
    local
      list<Integer> eindex,vindx;
      list<list<Integer>> othercomps;
      Boolean b,b1;
      BackendDAE.StrongComponents comps,acc;
      BackendDAE.StrongComponent comp,comp1;   
      Option<list<tuple<Integer, Integer, BackendDAE.Equation>>> ojac;
      BackendDAE.JacobianType jacType;
    case (_,_,{},_,_)
      then (listReverse(iAcc),iRunMatching);
    // don't tear linear system as long as we do not handle them 
    // as linear system while the runtime
    case (_,_,
      (comp as BackendDAE.EQUATIONSYSTEM(eqns=eindex,vars=vindx,jac=ojac,jacType=jacType))::comps,_,_)
      equation
        equality(jacType = BackendDAE.JAC_TIME_VARYING());
        true = Flags.isSet(Flags.LINEAR_TEARING);
        (comp1,true) = tearingSystemNew1_1(isyst,ishared,eindex,vindx,ojac,jacType);
        (acc,b1) = tearingSystemNew1(isyst,ishared,comps,true,comp1::iAcc);
      then
        (acc,b1);
    // tearing of non-linear systems
    case (_,_,
      (comp as BackendDAE.EQUATIONSYSTEM(eqns=eindex,vars=vindx,jac=ojac,jacType=jacType))::comps,_,_)
      equation
        failure(equality(jacType = BackendDAE.JAC_TIME_VARYING()));
        (comp1,true) = tearingSystemNew1_1(isyst,ishared,eindex,vindx,ojac,jacType);
        (acc,b1) = tearingSystemNew1(isyst,ishared,comps,true,comp1::iAcc);
      then
        (acc,b1);        
    // only continues part of a mixed system
    case (_,_,(comp as BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=comp1,disc_eqns=eindex,disc_vars=vindx))::comps,_,_)
      equation
        true = Flags.isSet(Flags.NO_MIXED_TEARING);
        (comp1::{},true) = tearingSystemNew1(isyst,ishared,{comp1},false,{});
        (acc,b1) = tearingSystemNew1(isyst,ishared,comps,true,BackendDAE.MIXEDEQUATIONSYSTEM(comp1,eindex,vindx)::iAcc);
      then
        (acc,b1);
    // mixed and continues part
    case (_,_,(comp as BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=comp1,disc_eqns=eindex,disc_vars=vindx))::comps,_,_)
      equation
        false = Flags.isSet(Flags.NO_MIXED_TEARING);
        (eindex,vindx) = BackendDAETransform.getEquationAndSolvedVarIndxes(comp);
        (comp1,true) = tearingSystemNew1_1(isyst,ishared,eindex,vindx,NONE(),BackendDAE.JAC_NO_ANALYTIC());
        (acc,b1) = tearingSystemNew1(isyst,ishared,comps,true,comp1::iAcc);
      then
        (acc,b1);
    case (_,_,comp::comps,_,_)
      equation
        (acc,b) = tearingSystemNew1(isyst,ishared,comps,iRunMatching,comp::iAcc);
      then
        (acc,b);
  end matchcontinue;  
end tearingSystemNew1;

protected function tearingSystemNew1_1 "function tearingSystemNew1
  author: Frenkel TUD 2012-05"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input list<Integer> eindex;
  input list<Integer> vindx;
  input Option<list<tuple<Integer, Integer, BackendDAE.Equation>>> ojac;
  input BackendDAE.JacobianType jacType;
  output BackendDAE.StrongComponent ocomp;
  output Boolean outRunMatching;
protected
  list<Integer> tvars,residual,unsolvables;
  list<list<Integer>> othercomps;
  BackendDAE.EqSystem syst,subsyst;
  BackendDAE.Shared shared;   
  array<Integer> ass1,ass2,columark,number,lowlink;
  Integer size,tornsize,mark;
  list<BackendDAE.Equation> eqn_lst; 
  list<BackendDAE.Var> var_lst;    
  BackendDAE.Variables vars;
  BackendDAE.EquationArray eqns;
  BackendDAE.IncidenceMatrix m,m1;
  BackendDAE.IncidenceMatrix mt,mt1;      
  BackendDAE.AdjacencyMatrixEnhanced me;
  BackendDAE.AdjacencyMatrixTEnhanced meT;
  array<list<Integer>> mapEqnIncRow;
  array<Integer> mapIncRowEqn;
algorithm
  // generate Subsystem to get the incidence matrix
  size := listLength(vindx);
  eqn_lst := BackendEquation.getEqns(eindex,BackendEquation.daeEqns(isyst));  
  eqns := BackendEquation.listEquation(eqn_lst);      
  var_lst := List.map1r(vindx, BackendVariable.getVarAt, BackendVariable.daeVars(isyst));
  vars := BackendVariable.listVar1(var_lst);
  subsyst := BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),{});
  (subsyst,m,mt,_,_) := BackendDAEUtil.getIncidenceMatrixScalar(subsyst, BackendDAE.NORMAL());
  //  IndexReduction.dumpSystemGraphML(subsyst,ishared,NONE(),"System" +& intString(size) +& ".graphml");
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEqSystem, subsyst);

  (me,meT,mapEqnIncRow,mapIncRowEqn) := BackendDAEUtil.getAdjacencyMatrixEnhancedScalar(subsyst,ishared);
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpAdjacencyMatrixEnhanced,me);
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpAdjacencyMatrixTEnhanced,meT);
  //  IndexReduction.dumpSystemGraphMLEnhanced(subsyst,shared,me,meT);
      
  /*   m1 := incidenceMatrixfromEnhanced(me);
       Matching.matchingExternalsetIncidenceMatrix(size,size,m1);
       BackendDAEEXT.matching(size,size,5,-1,1.0,1);
       ass1 := arrayCreate(size,-1);
       ass2 := arrayCreate(size,-1);
       BackendDAEEXT.getAssignment(ass1,ass2);         
       Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpMatching,ass1);
       Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpMatching,ass2);          
  */  
  // do cheap matching until a maximum matching is there if
  // cheap matching stucks select additional tearing variable and continue
  ass1 := arrayCreate(size,-1);
  ass2 := arrayCreate(size,-1);

  // get all unsolvable variables
  unsolvables := getUnsolvableVars(1,size,meT,{});
  Debug.fcall(Flags.TEARING_DUMP, print,"Unsolvable Vars:\n"); 
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.debuglst,(unsolvables,intString,", ","\n"));
     
  columark := arrayCreate(size,-1);
  (tvars,mark) := tearingSystemNew2(unsolvables,me,meT,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,1,{});
  ass1 := List.fold(tvars,unassignTVars,ass1);
  // unmatched equations are residual equations
  residual := Matching.getUnassigned(size,ass2,{});
  //  BackendDump.dumpMatching(ass1);
  Debug.fcall(Flags.TEARING_DUMP, print,"TearingVars:\n"); 
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.debuglst,(tvars,intString,", ","\nResidualEquations:\n"));
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.debuglst,(residual,intString,", ","\n")); 
  //  subsyst := BackendDAEUtil.setEqSystemMatching(subsyst,BackendDAE.MATCHING(ass1,ass2,{}));
  //  IndexReduction.dumpSystemGraphML(subsyst,ishared,NONE(),"TornSystem" +& intString(size) +& ".graphml");
  // check if tearing make sense
  tornsize := listLength(tvars);
  true := intLt(tornsize,size-1);
  // run tarjan to get order of other equations
  m1 := arrayCreate(size,{});
  mt1 := arrayCreate(size,{});
  m1 := getOtherEqSysIncidenceMatrix(m,size,1,ass2,ass1,m1);
  mt1 := getOtherEqSysIncidenceMatrix(mt,size,1,ass1,ass2,mt1);
  //  subsyst := BackendDAE.EQSYSTEM(vars,eqns,SOME(m1),SOME(mt1),BackendDAE.MATCHING(ass1,ass2,{}));
  //  BackendDump.printEqSystem(subsyst);
  number := arrayCreate(size,0);
  lowlink := arrayCreate(size,0);        
  number := setIntArray(residual,number,size);
  (_,_,othercomps) := BackendDAETransform.strongConnectMain(m1, mt1, ass1, ass2, number, lowlink, size, 0, 1, {}, {});        
  Debug.fcall(Flags.TEARING_DUMP, print, "OtherEquationsOrder:\n"); 
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.dumpComponentsOLD,othercomps); 
  Debug.fcall(Flags.TEARING_DUMP, print, "\n");
  // calculate influence of tearing vars in residual equations 
  mt1 := arrayCreate(size, {});
  mark := getDependenciesOfVars(othercomps, ass1, ass2, m, mt1, columark, mark);
  (residual, mark) := sortResidualDepentOnTVars(residual, tvars, ass1, m, mt1, columark, mark);
  // handle system in case of liniear and other cases 
  //(osyst,oshared,outRunMatching) := tearingSystemNew4(jacType,isyst,ishared,subsyst,tvars,residual,ass1,ass2,othercomps,eindex,vindx,mapEqnIncRow,mapIncRowEqn);
  (ocomp,outRunMatching) := tearingSystemNew4_1(jacType,isyst,ishared,subsyst,tvars,residual,ass1,ass2,othercomps,eindex,vindx,mapEqnIncRow,mapIncRowEqn,columark,mark);
  Debug.fcall(Flags.TEARING_DUMP, print,Util.if_(outRunMatching,"Ok system torn\n","System not torn\n"));
end tearingSystemNew1_1;

protected function sortResidualDepentOnTVars
  input list<Integer> iResiduals;
  input list<Integer> iTVars;
  input array<Integer> ass1;
  input BackendDAE.IncidenceMatrix m;
  input array<list<Integer>> mT;
  input array<Integer> visited;
  input Integer iMark;
  output list<Integer> oResiduals;
  output Integer oMark;
protected
  Integer size;
  list<list<Integer>> maplst;
  array<list<Integer>> map;
  array<Integer> eqnLocalGlobal,varGlobalLocal,v1,v2;
algorithm
  // eqn - local - Global indices
  eqnLocalGlobal := listArray(iResiduals);
  // var - global local indices
  varGlobalLocal := arrayCreate(arrayLength(m),-1);
  varGlobalLocal := getGlobalLocal(iTVars,1,varGlobalLocal);
  // generate list of map[residual]=tvars
  // change indices in map to local
  (oMark,maplst) := tVarsofResidualEqns(iResiduals,m,ass1,mT,varGlobalLocal,visited,iMark,{});
  map := listArray(maplst);
  // get for each residual a tvar
  size := arrayLength(map);
  Matching.matchingExternalsetIncidenceMatrix(size,size,map);
  BackendDAEEXT.matching(size,size,5,-1,1.0,1);
  v1 := arrayCreate(size,-1);
  v2 := arrayCreate(size,-1);
  BackendDAEEXT.getAssignment(v2,v1);
  //  BackendDump.dumpIncidenceMatrix(map);
  //  BackendDump.dumpMatching(v1);
  //  BackendDump.dumpMatching(v2);
  // sort residuals depent on matching to tvars
  oResiduals := getTVarResiduals(size,v1,eqnLocalGlobal,{});
  //  print("iResiduals " +& stringDelimitList(List.map(iResiduals,intString),"\n") +& "\n");
  //  print("oResiduals " +& stringDelimitList(List.map(oResiduals,intString),"\n") +& "\n");
end sortResidualDepentOnTVars;

protected function getTVarResiduals
  input Integer index;
  input array<Integer> v1;
  input array<Integer> eqnLocalGlobal;
  input list<Integer> iAcc;
  output list<Integer> oAcc;
algorithm
  oAcc := match(index,v1,eqnLocalGlobal,iAcc)
    local
      Integer e;
    case (0,_,_,_) then iAcc;
    case (_,_,_,_)
      equation
        e = v1[index];
        e = eqnLocalGlobal[e];
      then
        getTVarResiduals(index-1,v1,eqnLocalGlobal,e::iAcc);
  end match;
end getTVarResiduals;

protected function getGlobalLocal
  input list<Integer> iTVars;
  input Integer index;
  input array<Integer> iVarGlobalLocal;
  output array<Integer> oVarGlobalLocal;
algorithm
oVarGlobalLocal := 
  match(iTVars,index,iVarGlobalLocal)
    local
      Integer i;
      list<Integer> tvars;
    case ({},_,_) then iVarGlobalLocal;
    case (i::tvars,_,_)
      equation
        _= arrayUpdate(iVarGlobalLocal,i,index);
      then
        getGlobalLocal(tvars,index+1,iVarGlobalLocal);
  end match;
end getGlobalLocal;

protected function tVarsofResidualEqns
  input list<Integer> iEqns;
  input BackendDAE.IncidenceMatrix m;
  input array<Integer> ass1;
  input array<list<Integer>> mT;
  input array<Integer> varGlobalLocal;
  input array<Integer> visited;
  input Integer iMark;
  input list<list<Integer>> iAcc;
  output Integer oMark;
  output list<list<Integer>> oAcc;
algorithm
  (oMark,oAcc) := match(iEqns,m,ass1,mT,varGlobalLocal,visited,iMark,iAcc)
    local
      Integer e;
      list<Integer> eqns,vars,tvars;
    case ({},_,_,_,_,_,_,_) then (iMark,listReverse(iAcc));
    case (e::eqns,_,_,_,_,_,_,_)
      equation
        vars = List.select(m[e], Util.intPositive);
        tvars = tVarsofEqn(vars,ass1,mT,visited,iMark,{});
        // change indices to local
        tvars = List.map1r(tvars,arrayGet,varGlobalLocal);
        (oMark,oAcc) = tVarsofResidualEqns(eqns,m,ass1,mT,varGlobalLocal,visited,iMark+1,tvars::iAcc);
      then
        (oMark,oAcc);
  end match;
end tVarsofResidualEqns;

protected function getDependenciesOfVars
  input list<list<Integer>> iComps;
  input array<Integer> ass1;
  input array<Integer> ass2;
  input BackendDAE.IncidenceMatrix m;
  input array<list<Integer>> mT;
  input array<Integer> visited;
  input Integer iMark;
  output Integer oMark;
algorithm
  oMark := match(iComps, ass1, ass2, m, mT, visited, iMark)
    local
      Integer c, v;
      list<Integer> comp, tvars, vars;
      list<list<Integer>> comps;
    
    case ({}, _, _, _, _, _, _)
    then iMark;
    
    case ({c}::comps, _, _, _, _, _, _) equation
      // get var of eqn
      v = ass2[c];
      // get TVars of Eqn
      vars = List.select(m[c], Util.intPositive);
      tvars = tVarsofEqn(vars, ass1, mT, visited, iMark, {});
      // update map
      _ = arrayUpdate(mT, v, tvars);
    then getDependenciesOfVars(comps, ass1, ass2, m, mT, visited, iMark+1);
    
    case (comp::comps, _, _, _, _, _, _) equation
      // get var of eqns
      vars = List.map1r(comp,arrayGet,ass2);
      // get TVars of Eqns
      tvars = tVarsofEqns(comp, m, ass1, mT, visited, iMark, {});
      // update map
      _ = List.fold1r(vars, arrayUpdate, tvars, mT);
    then getDependenciesOfVars(comps, ass1, ass2, m, mT, visited, iMark+1);
  end match; 
end getDependenciesOfVars;

protected function tVarsofEqns
  input list<Integer> iEqns;
  input BackendDAE.IncidenceMatrix m;
  input array<Integer> ass1;
  input array<list<Integer>> mT;
  input array<Integer> visited;
  input Integer iMark;
  input list<Integer> iAcc;
  output list<Integer> oAcc;
algorithm
  oAcc := match(iEqns, m, ass1, mT, visited, iMark, iAcc)
    local
      Integer e;
      list<Integer> eqns, vars, tvars;
      
    case ({}, _, _, _, _, _, _)
    then iAcc;
    
    case (e::eqns, _, _, _, _, _, _) equation
      vars = List.select(m[e], Util.intPositive);
      tvars = tVarsofEqn(vars, ass1, mT, visited, iMark, iAcc);
    then tVarsofEqns(eqns, m, ass1, mT, visited, iMark, tvars);
  end match;
end tVarsofEqns;

protected function tVarsofEqn
  input list<Integer> iVars;
  input array<Integer> ass1;
  input array<list<Integer>> mT;
  input array<Integer> visited;
  input Integer iMark;
  input list<Integer> iAcc;
  output list<Integer> oAcc;
algorithm
  oAcc := matchcontinue(iVars,ass1,mT,visited,iMark,iAcc)
    local
      Integer v;
      list<Integer> vars,tvars;
    case ({},_,_,_,_,_) then iAcc;
    case (v::vars,_,_,_,_,_)
      equation
        true = intLt(ass1[v],0);
        tvars = uniqueIntLst(v,iMark,visited,iAcc);
      then
        tVarsofEqn(vars,ass1,mT,visited,iMark,tvars);
    case (v::vars,_,_,_,_,_) equation
      tvars = List.fold2(mT[v],uniqueIntLst,iMark,visited,iAcc);
    then tVarsofEqn(vars, ass1, mT, visited, iMark, tvars);
  end matchcontinue;
end tVarsofEqn;

protected function getUnsolvableVars
"function getUnsolvableVars
  author: Frenkel TUD 2012-08"
  input Integer index;
  input Integer size;
  input BackendDAE.AdjacencyMatrixTEnhanced meT;
  input list<Integer> iAcc;
  output list<Integer> oAcc;
algorithm
  oAcc := matchcontinue(index,size,meT,iAcc)
    local
      BackendDAE.AdjacencyMatrixElementEnhanced elem;
      list<Integer> acc;
      Boolean b;
    case(_,_,_,_)
      equation
        true = intLe(index,size);
        elem = meT[index];
        b = unsolvable(elem);
        acc = List.consOnTrue(b, index, iAcc);
      then
       getUnsolvableVars(index+1,size,meT,acc);
    case(_,_,_,_)
      then
       iAcc;
  end matchcontinue;
end getUnsolvableVars;

protected function unsolvable
"function unsolvable
  author: Frenkel TUD 2012-08"
  input BackendDAE.AdjacencyMatrixElementEnhanced elem;
  output Boolean b;
algorithm
  b := match(elem)
    local
      Integer e;
      BackendDAE.AdjacencyMatrixElementEnhanced rest;
      Boolean b1;
    case ({}) then true;
    case ((e,BackendDAE.SOLVABILITY_SOLVED())::rest)
      equation
        b1 = intLe(e,0);
        b1 = Debug.bcallret1(b1, unsolvable, rest, false);
      then 
        b1;
    case ((e,BackendDAE.SOLVABILITY_CONSTONE())::rest)
      equation
        b1 = intLe(e,0);
        b1 = Debug.bcallret1(b1, unsolvable, rest, false);
      then 
        b1;
    case ((e,BackendDAE.SOLVABILITY_CONST())::rest)
      equation
        b1 = intLe(e,0);
        b1 = Debug.bcallret1(b1, unsolvable, rest, false);
      then 
        b1;
    case ((e,BackendDAE.SOLVABILITY_PARAMETER(b=false))::rest)
      then 
        unsolvable(rest);
    case ((e,BackendDAE.SOLVABILITY_PARAMETER(b=true))::rest)
      equation
        b1 = intLe(e,0);
        b1 = Debug.bcallret1(b1, unsolvable, rest, false);
      then 
        b1;
    case ((e,BackendDAE.SOLVABILITY_TIMEVARYING(b=false))::rest)
      then 
        unsolvable(rest);
    case ((e,BackendDAE.SOLVABILITY_TIMEVARYING(b=true))::rest)
      then 
        unsolvable(rest);
    case ((e,BackendDAE.SOLVABILITY_NONLINEAR())::rest)
      then 
        unsolvable(rest);
    case ((e,BackendDAE.SOLVABILITY_UNSOLVABLE())::rest)
      then 
        unsolvable(rest);
  end match;
end unsolvable;

protected function setIntArray
"function setIntArray
  author: Frenkel TUD 2012-08"
  input list<Integer> inLst;
  input array<Integer> arr;
  input Integer value;
  output array<Integer> oarr;
algorithm
  oarr := match(inLst,arr,value)
    local 
      Integer indx;
      list<Integer> rest;
    case(indx::rest,_,_)
      equation
        _= arrayUpdate(arr,indx,value);
      then
        setIntArray(rest,arr,value);
    case({},_,_) then arr;
  end match;
end setIntArray;

protected function incidenceMatrixfromEnhanced
"function incidenceMatrixfromEnhanced
  author: Frenkel TUD 2012-08"
  input BackendDAE.AdjacencyMatrixEnhanced me;
  output BackendDAE.IncidenceMatrix m;
algorithm
  m := Util.arrayMap(me,incidenceMatrixElementfromEnhanced);
end incidenceMatrixfromEnhanced;

protected function incidenceMatrixElementfromEnhanced
"function incidenceMatrixElementfromEnhanced
  author: Frenkel TUD 2012-08"
  input BackendDAE.AdjacencyMatrixElementEnhanced iRow;
  output BackendDAE.IncidenceMatrixElement oRow;
algorithm
  oRow := List.map(List.sort(iRow,AdjacencyMatrixElementEnhancedCMP), incidenceMatrixElementElementfromEnhanced);
end incidenceMatrixElementfromEnhanced;

protected function AdjacencyMatrixElementEnhancedCMP
"function AdjacencyMatrixElementEnhancedCMP
  author: Frenkel TUD 2012-08"
  input tuple<Integer, BackendDAE.Solvability> inTplA;
  input tuple<Integer, BackendDAE.Solvability> inTplB;
  output Boolean b;
algorithm
  b := BackendDAEUtil.solvabilityCMP(Util.tuple22(inTplA),Util.tuple22(inTplB));
end AdjacencyMatrixElementEnhancedCMP;

protected function incidenceMatrixElementElementfromEnhanced
"function incidenceMatrixElementElementfromEnhanced
  author: Frenkel TUD 2012-08"
  input tuple<Integer, BackendDAE.Solvability> inTpl;
  output Integer oI;
algorithm
  oI := match(inTpl)
    local 
      Integer i;
      Boolean b;
    case ((i,BackendDAE.SOLVABILITY_SOLVED())) then i;
    case ((i,BackendDAE.SOLVABILITY_CONSTONE())) then i;
    case ((i,BackendDAE.SOLVABILITY_CONST())) then i;
    case ((i,BackendDAE.SOLVABILITY_PARAMETER(b=_)))
      equation
        i = Util.if_(intLt(i,0),i,-i);
      then i;
    case ((i,BackendDAE.SOLVABILITY_TIMEVARYING(b=_)))
      equation
        i = Util.if_(intLt(i,0),i,-i);
      then i;
    case ((i,BackendDAE.SOLVABILITY_NONLINEAR()))
      equation
        i = Util.if_(intLt(i,0),i,-i);
       then i;
    case ((i,BackendDAE.SOLVABILITY_UNSOLVABLE()))
      equation
        i = Util.if_(intLt(i,0),i,-i);
      then i;
  end match;
end incidenceMatrixElementElementfromEnhanced;

protected function getOtherEqSysIncidenceMatrix "function getOtherEqSysIncidenceMatrix
  author: Frenkel TUD 2012-05"
  input BackendDAE.IncidenceMatrix m;
  input Integer size;
  input Integer index;
  input array<Integer> skip;
  input array<Integer> rowskip;
  input BackendDAE.IncidenceMatrix mnew;
  output BackendDAE.IncidenceMatrix outMNew;
algorithm
  outMNew := matchcontinue(m,size,index,skip,rowskip,mnew)
    local
      list<Integer> row;
    case (_,_,_,_,_,_)
      equation
        true = intGt(index,size);
      then
        mnew;
    case (_,_,_,_,_,_)
      equation
        true = intGt(skip[index],0);
        row = List.select(m[index], Util.intPositive);
        row = List.select1r(row,isAssigned,rowskip);
        _ = arrayUpdate(mnew,index,row);
      then
        getOtherEqSysIncidenceMatrix(m,size,index+1,skip,rowskip,mnew);
    case (_,_,_,_,_,_)
      equation
        _ = arrayUpdate(mnew,index,{});
      then
        getOtherEqSysIncidenceMatrix(m,size,index+1,skip,rowskip,mnew);
  end matchcontinue;
end getOtherEqSysIncidenceMatrix;

protected function unassignTVars "function unassignTVars
  author: Frenkel TUD 2012-05"
  input Integer v;
  input array<Integer> inAss;
  output array<Integer> outAss;
algorithm
  outAss := arrayUpdate(inAss,v,-1);
end unassignTVars;

protected function isAssigned "function isAssigned
  author: Frenkel TUD 2012-05"
  input array<Integer> ass;
  input Integer i;
  output Boolean b;
algorithm
  b := intGt(ass[i],0);
end isAssigned;

protected function isUnAssigned "function isUnAssigned
  author: Frenkel TUD 2012-05"
  input array<Integer> ass;
  input Integer i;
  output Boolean b;
algorithm
  b := intLt(ass[i],1);
end isUnAssigned;

protected function isMarked "function isMarked
  author: Frenkel TUD 2012-05"
  input tuple<array<Integer>,Integer> inTpl;
  input Integer v;
  output Boolean b;
protected
  array<Integer> markarray;
  Integer mark;
algorithm
  (markarray,mark) := inTpl;
  b := intEq(markarray[v],mark);
end isMarked;

protected function selectVarsWithMostEqns "function selectVarWithMostEqns
  author: Frenkel TUD 2012-05"
  input list<Integer> vars;
  input array<Integer> ass2;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input list<Integer> iVars;
  input Integer eqns;
  output list<Integer> oVars;
algorithm
  oVars := matchcontinue(vars,ass2,mt,iVars,eqns)
    local
      list<Integer> rest,vlst;
      Integer e,v;
    case ({},_,_,_,_) then iVars;
    case (v::rest,_,_,_,_)
      equation
        e = calcSolvabilityWight(mt[v],ass2);
        //  print("Var " +& intString(v) +& "has w= " +& intString(e) +& "\n");
        true = intGe(e,eqns);
        vlst = List.consOnTrue(intEq(e,eqns),v,iVars);
        ((vlst,e)) = Util.if_(intGt(e,eqns),({v},e),(vlst,eqns));
        //  print("max is  " +& intString(eqns) +& "\n");
        //  BackendDump.debuglst((vlst,intString,", ","\n"));
      then
        selectVarsWithMostEqns(rest,ass2,mt,vlst,e);
    case (_::rest,_,_,_,_)
      then
        selectVarsWithMostEqns(rest,ass2,mt,iVars,eqns);
  end matchcontinue;
end selectVarsWithMostEqns;

protected function selectVarWithMostPoints "function selectVarWithMostPoints
  author: Frenkel TUD 2012-05"
  input list<Integer> vars;
  input array<Integer> points;
  input Integer iVar;
  input Integer defp;
  output Integer oVar;
algorithm
  oVar := matchcontinue(vars,points,iVar,defp)
    local
      list<Integer> rest;
      Integer p,v;
    case ({},_,_,_) then iVar;
    case (v::rest,_,_,_)
      equation
        //  print("Var " +& intString(v));
        p = points[v];
        //  print(" has " +& intString(p) +& " Points\n");
        true = intGt(p,defp);
        //  print("max is  " +& intString(defp) +& "\n");
      then
        selectVarWithMostPoints(rest,points,v,p);
    case (_::rest,_,_,_)
      then
        selectVarWithMostPoints(rest,points,iVar,defp);
  end matchcontinue;
end selectVarWithMostPoints;

protected function addEqnWights
 input Integer e;
 input BackendDAE.AdjacencyMatrixEnhanced m;
 input array<Integer> ass1;
 input array<Integer> iPoints;
 output array<Integer> oPoints;
algorithm
 oPoints := matchcontinue(e,m,ass1,iPoints)
   local
       Integer v1,v2;
       array<Integer> points;
     case (_,_,_,_)
       equation
         ((v1,_)::(v2,_)::{}) = List.removeOnTrue(ass1, isAssignedSaveEnhanced, m[e]); 
          points = arrayUpdate(iPoints,v1,iPoints[v1]+5);
          points = arrayUpdate(iPoints,v2,points[v2]+5);
       then
         points;
     else
       iPoints;
 end matchcontinue;
end addEqnWights;

protected function addOneEdgeEqnWights
 input Integer v;
 input tuple<BackendDAE.AdjacencyMatrixEnhanced,BackendDAE.AdjacencyMatrixTEnhanced> mmt;
 input array<Integer> ass1;
 input array<Integer> iPoints;
 output array<Integer> oPoints;
algorithm
 oPoints := matchcontinue(v,mmt,ass1,iPoints)
   local
       BackendDAE.AdjacencyMatrixEnhanced m;
       BackendDAE.AdjacencyMatrixTEnhanced mt;
       list<Integer> elst;
       Integer e;
       array<Integer> points;
     case (_,(m,mt),_,_)
       equation
         elst = List.fold2(mt[v],eqnsWithOneUnassignedVar,m,ass1,{});
          e = listLength(elst);
          points = arrayUpdate(iPoints,v,iPoints[v]+e);
       then
         points;
     else
       iPoints;
 end matchcontinue;
end addOneEdgeEqnWights;

protected function calcVarWights
 input Integer v;
 input BackendDAE.AdjacencyMatrixTEnhanced mt;
 input array<Integer> ass2;
 input array<Integer> iPoints;
 output array<Integer> oPoints;
protected
 Integer p;
algorithm
  p := calcSolvabilityWight(mt[v],ass2);
  oPoints := arrayUpdate(iPoints,v,p);
end calcVarWights;

protected function calcSolvabilityWight
  input BackendDAE.AdjacencyMatrixElementEnhanced inRow;
  input array<Integer> ass2;
  output Integer w;
algorithm
  w := List.fold1(inRow,solvabilityWightsnoStates,ass2,0);
end calcSolvabilityWight;

public function solvabilityWightsnoStates "function: solvabilityWights
  author: Frenkel TUD 2012-05"
  input tuple<Integer,BackendDAE.Solvability> inTpl;
  input array<Integer> ass;
  input Integer iW;
  output Integer oW;
algorithm
  oW := matchcontinue(inTpl,ass,iW)
    local
      BackendDAE.Solvability s;
      Integer v,w;
    case((v,s),_,_)
      equation
        true = intGt(v,0);
        false = intGt(ass[v], 0);
        w = solvabilityWights(s);
      then
        intAdd(w,iW);
    else then iW;
  end matchcontinue;
end solvabilityWightsnoStates;

public function solvabilityWights "function: solvabilityWights
  author: Frenkel TUD 2012-05,
  return a integer for the solvability, this function is used
  to calculade wights for variables to select the tearing variable."
  input BackendDAE.Solvability solva;
  output Integer i;
algorithm
  i := match(solva)
    case BackendDAE.SOLVABILITY_SOLVED() then 0;
    case BackendDAE.SOLVABILITY_CONSTONE() then 2;
    case BackendDAE.SOLVABILITY_CONST() then 5;
    case BackendDAE.SOLVABILITY_PARAMETER(b=false) then 0;
    case BackendDAE.SOLVABILITY_PARAMETER(b=true) then 50;
    case BackendDAE.SOLVABILITY_TIMEVARYING(b=false) then 0;
    case BackendDAE.SOLVABILITY_TIMEVARYING(b=true) then 100;
    case BackendDAE.SOLVABILITY_NONLINEAR() then 200;
    case BackendDAE.SOLVABILITY_UNSOLVABLE() then 300;
  end match;
end solvabilityWights;

protected function selectTearingVar "function selectTearingVar
  author: Frenkel TUD 2012-05"
  input BackendDAE.Variables vars;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  output Integer tearingVar;
algorithm
  tearingVar := matchcontinue(vars,ass1,ass2,m,mt)
    local
      list<Integer> states,eqns;
      Integer tvar;
      Integer size,varsize;
      array<Integer> points;
    // if vars there with no liniear occurence in any equation use all of them
/*    case(_,_,_,_)
      equation
      then
          
    // if states there use them as tearing variables
    case(_,_,_,_)
      equation
        (_,states) = BackendVariable.getAllStateVarIndexFromVariables(vars);
        states = List.removeOnTrue(ass1, isAssigned, states);
        true = intGt(listLength(states),0);
        tvar = selectVarWithMostEqns(states,ass2,mt,-1,-1);
      then
        tvar;
*/
    /* if there is a variable unsolvable select it */
    case(_,_,_,_,_)
      equation
        tvar = getUnsolvableVarsConsiderMatching(1,BackendVariable.varsSize(vars),mt,ass1,ass2);
      then
        tvar;
       
    case(_,_,_,_,_)
      equation
        varsize = BackendVariable.varsSize(vars);
        states = Matching.getUnassigned(varsize,ass1,{});
        Debug.fcall(Flags.TEARING_DUMP,  print,"selectTearingVar Candidates:\n"); 
        Debug.fcall(Flags.TEARING_DUMP,  BackendDump.debuglst,(states,intString,", ","\n"));  
        size = listLength(states);
        true = intGt(size,0);
        points = arrayCreate(varsize,0);
        points = List.fold2(states, calcVarWights,mt,ass2,points);
        eqns = Matching.getUnassigned(arrayLength(m),ass2,{});
        points = List.fold2(eqns,addEqnWights,m,ass1,points);
        //points = List.fold1(states,discriminateDiscrete,vars,points);
        //points = List.fold2(states,addOneEdgeEqnWights,(m,mt),ass1,points);
         Debug.fcall(Flags.TEARING_DUMP,  BackendDump.dumpMatching,points);
        tvar = selectVarWithMostPoints(states,points,-1,-1);
        
        //states = selectVarsWithMostEqns(states,ass2,mt,{},-1);
        //  print("VarsWithMostEqns:\n"); 
        //  BackendDump.debuglst((states,intString,", ","\n"));        
        //tvar = selectVarWithMostEqnsOneEdge(states,ass1,m,mt,-1,-1);
      then
        tvar;        
      else
    equation
        print("selectTearingVar failed because no unmatched var!\n");
      then
        fail();
  end matchcontinue;  
end selectTearingVar;

protected function getUnsolvableVarsConsiderMatching
"function getUnsolvableVarsConsiderMatching
  author: Frenkel TUD 2012-08"
  input Integer index;
  input Integer size;
  input BackendDAE.AdjacencyMatrixTEnhanced meT;
  input array<Integer> ass1;
  input array<Integer> ass2;
  output Integer Unsolvable;
algorithm
  Unsolvable := matchcontinue(index,size,meT,ass1,ass2)
    local
      BackendDAE.AdjacencyMatrixElementEnhanced elem;
      Boolean b;
    case(_,_,_,_,_)
      equation
        true = intLe(index,size);
        /* unmatched var */
        true = intLt(ass1[index],0);
        elem = meT[index];
        /* consider only unmatched eqns */
        elem = removeMatched(elem,ass2,{});
        true = unsolvable(elem);
      then
       index;
    case(_,_,_,_,_)
      equation
        true = intLe(index,size);
      then
       getUnsolvableVarsConsiderMatching(index+1,size,meT,ass1,ass2);
  end matchcontinue;
end getUnsolvableVarsConsiderMatching;

protected function removeMatched
"function removeMatched
  author: Frenkel TUD 2012-08"
  input BackendDAE.AdjacencyMatrixElementEnhanced elem;
  input array<Integer> ass2;
  input BackendDAE.AdjacencyMatrixElementEnhanced iAcc;
  output BackendDAE.AdjacencyMatrixElementEnhanced oAcc;
algorithm
  oAcc := matchcontinue(elem,ass2,iAcc)
    local
      Integer e;
      BackendDAE.AdjacencyMatrixElementEnhanced rest;
      BackendDAE.Solvability s;
    case ({},_,_) then iAcc;
    case ((e,s)::rest,_,_)
      equation
        true = intLt(ass2[e],0);
      then
        removeMatched(rest,ass2,(e,s)::iAcc);
    case ((e,s)::rest,_,_)
      then
        removeMatched(rest,ass2,iAcc);
  end matchcontinue;
end removeMatched;

protected function discriminateDiscrete
"function discriminateDiscrete
  author: Frenkel TUD 2012-08"
 input Integer v;
 input BackendDAE.Variables vars;
 input array<Integer> iPoints;
 output array<Integer> oPoints;
protected
 Integer p;
 Boolean b;
 BackendDAE.Var var;
algorithm
  var := BackendVariable.getVarAt(vars, v);
  b := BackendVariable.isVarDiscrete(var);
  p := iPoints[v];
  p := Util.if_(b,intDiv(p,10),p);
  oPoints := arrayUpdate(iPoints,v,p);
end discriminateDiscrete;

protected function selectVarWithMostEqnsOneEdge
"function selectVarWithMostEqnsOneEdge
  author: Frenkel TUD 2012-08"
  input list<Integer> vars;
  input array<Integer> ass1;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input Integer defaultVar;
  input Integer eqns;
  output Integer var;
algorithm
  var := matchcontinue(vars,ass1,m,mt,defaultVar,eqns)
    local
      list<Integer> rest,elst;
      Integer e,v;
    case ({},_,_,_,_,_) then defaultVar;
    case (v::rest,_,_,_,_,_)
      equation
        elst = List.fold2(mt[v],eqnsWithOneUnassignedVar,m,ass1,{});
        e = listLength(elst);
        //  print("Var " +& intString(v) +& " has " +& intString(e) +& " one eqns\n");
        true = intGt(e,eqns);
      then
        selectVarWithMostEqnsOneEdge(rest,ass1,m,mt,v,e);
    case (_::rest,_,_,_,_,_)
      then
        selectVarWithMostEqnsOneEdge(rest,ass1,m,mt,defaultVar,eqns);
  end matchcontinue;
end selectVarWithMostEqnsOneEdge;

protected function eqnsWithOneUnassignedVar "function: eqnsWithOneUnassignedVar
  author: Frenkel TUD 2012-05"
  input tuple<Integer,BackendDAE.Solvability> inTpl;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input array<Integer> ass;
  input list<Integer> iLst;
  output list<Integer> oLst;
algorithm
  oLst := matchcontinue(inTpl,m,ass,iLst)
    local
      BackendDAE.Solvability s;
      Integer e;
      BackendDAE.AdjacencyMatrixElementEnhanced vars;
    case((e,s),_,_,_)
      equation
        true = intGt(e,0);
        vars = List.removeOnTrue(ass, isAssignedSaveEnhanced, m[e]);
        //  print("Eqn " +& intString(e) +& " has " +& intString(listLength(vars)) +& " vars\n");
        true = intEq(listLength(vars), 2);
      then
        e::iLst;
    else then iLst;            
  end matchcontinue; 
end eqnsWithOneUnassignedVar;

protected function markEqns "function markEqns
  author: Frenkel TUD 2012-05"
  input list<Integer> eqns;
  input array<Integer> columark;
  input Integer mark;
algorithm
  _ := match(eqns,columark,mark)
    local
      Integer e;
      list<Integer> rest;
    case({},_,_) then ();
    case(e::rest,_,_)
      equation
        _ = arrayUpdate(columark,e,mark);
        markEqns(rest,columark,mark);
      then
        ();
  end match; 
end markEqns;

protected function tearingSystemNew2 "function tearingSystemNew2
  author: Frenkel TUD 2012-05"
  input list<Integer> unsolvables;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input array<list<Integer>> mapEqnIncRow;
  input array<Integer> mapIncRowEqn;    
  input Integer size;
  input BackendDAE.Variables vars;
  input BackendDAE.Shared ishared;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input array<Integer> columark;
  input Integer mark;
  input list<Integer> inTVars;
  output list<Integer> outTVars;
  output Integer oMark;
algorithm
  (outTVars,oMark) := matchcontinue(unsolvables,m,mt,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,mark,inTVars)
    local 
      Integer tvar;
      list<Integer> unassigned,rest;
      BackendDAE.AdjacencyMatrixElementEnhanced vareqns;
    case ({},_,_,_,_,_,_,_,_,_,_,_,_)
      equation
        // select tearing var
        tvar = selectTearingVar(vars,ass1,ass2,m,mt);
        //  print("Selected Var " +& intString(tvar) +& " as TearingVar\n");
        // mark tearing var
        _ = arrayUpdate(ass1,tvar,size*2);
        vareqns = List.removeOnTrue(ass2, isAssignedSaveEnhanced, mt[tvar]); 
        //vareqns = List.removeOnTrue((columark,mark), isMarked, vareqns); 
        //markEqns(vareqns,columark,mark);
        // cheap matching
        tearingBFS(vareqns,m,mt,mapEqnIncRow,mapIncRowEqn,size,ass1,ass2,columark,mark,{});

        /*  vlst = getUnnassignedFromArray(1,arrayLength(mt),ass1,vars,BackendVariable.getVarAt,0,{});
          elst = getUnnassignedFromArray(1,arrayLength(m),ass2,eqns,BackendDAEUtil.equationNth,-1,{});
          vars1 = BackendVariable.listVar1(vlst);
          eqns1 = BackendEquation.listEquation(elst);
          subsyst = BackendDAE.EQSYSTEM(vars1,eqns1,NONE(),NONE(),BackendDAE.NO_MATCHING());
          IndexReduction.dumpSystemGraphML(subsyst,ishared,NONE(),"System.graphml");
        */

        // check for unassigned vars, if there some rerun 
        unassigned = Matching.getUnassigned(size,ass1,{});
        (outTVars,oMark) = tearingSystemNew3(unassigned,{},m,mt,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,mark+1,tvar::inTVars);
      then
        (outTVars,oMark);
    case (tvar::rest,_,_,_,_,_,_,_,_,_,_,_,_)
      equation
        //  print("Selected Var " +& intString(tvar) +& " as TearingVar\n");
        // mark tearing var
        _ = arrayUpdate(ass1,tvar,size*2);
        vareqns = List.removeOnTrue(ass2, isAssignedSaveEnhanced, mt[tvar]); 
        //vareqns = List.removeOnTrue((columark,mark), isMarked, vareqns); 
        //markEqns(vareqns,columark,mark);
        // cheap matching
        tearingBFS(vareqns,m,mt,mapEqnIncRow,mapIncRowEqn,size,ass1,ass2,columark,mark,{});

        /*  vlst = getUnnassignedFromArray(1,arrayLength(mt),ass1,vars,BackendVariable.getVarAt,0,{});
          elst = getUnnassignedFromArray(1,arrayLength(m),ass2,eqns,BackendDAEUtil.equationNth,-1,{});
          vars1 = BackendVariable.listVar1(vlst);
          eqns1 = BackendEquation.listEquation(elst);
          subsyst = BackendDAE.EQSYSTEM(vars1,eqns1,NONE(),NONE(),BackendDAE.NO_MATCHING());
          IndexReduction.dumpSystemGraphML(subsyst,ishared,NONE(),"System.graphml");
        */
        // check for unassigned vars, if there some rerun 
        unassigned = Matching.getUnassigned(size,ass1,{});
        (outTVars,oMark) = tearingSystemNew3(unassigned,rest,m,mt,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,mark+1,tvar::inTVars);
      then
        (outTVars,oMark);
    else
      equation
        print("BackendDAEOptimize.tearingSystemNew2 failed!");
      then
        fail();  
  end matchcontinue; 
end tearingSystemNew2;

protected function getUnnassignedFromArray
  replaceable type Type_a subtypeof Any;
  replaceable type Type_b subtypeof Any;
  input Integer indx;
  input Integer size;
  input array<Integer> ass;
  input Type_b inTypeAArray;
  input FuncTypeType_aFromArray func;
  input Integer off;
  input list<Type_a> iALst;
  output list<Type_a> oALst;
  partial function FuncTypeType_aFromArray
    input Type_b inTypeB;
    input Integer indx;
    output Type_a outTypeA;
  end FuncTypeType_aFromArray;
algorithm
  oALst := matchcontinue(indx,size,ass,inTypeAArray,func,off,iALst)
    local
      Type_a a;
    case (_,_,_,_,_,_,_)
      equation
        true = intLe(indx,size);
        true = intLt(ass[indx],1);
        a = func(inTypeAArray,indx+off);
      then
        getUnnassignedFromArray(indx+1,size,ass,inTypeAArray,func,off,a::iALst);
    case (_,_,_,_,_,_,_)
      equation
        true = intLe(indx,size);
      then
        getUnnassignedFromArray(indx+1,size,ass,inTypeAArray,func,off,iALst);
    else
      listReverse(iALst); 
  end matchcontinue;
end getUnnassignedFromArray;

protected function tearingSystemNew3 "function tearingSystemNew3
  author: Frenkel TUD 2012-05"
  input list<Integer> unassigend;
  input list<Integer> unsolvables;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input array<list<Integer>> mapEqnIncRow;
  input array<Integer> mapIncRowEqn;    
  input Integer size;
  input BackendDAE.Variables vars;
  input BackendDAE.Shared ishared;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input array<Integer> columark;
  input Integer mark;
  input list<Integer> inTVars;
  output list<Integer> outTVars;
  output Integer oMark;
algorithm
  (outTVars,oMark) := match(unassigend,unsolvables,m,mt,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,mark,inTVars)
    local 
    case ({},_,_,_,_,_,_,_,_,_,_,_,_,_) then (inTVars,mark);
    else 
      equation
        (outTVars,oMark) = tearingSystemNew2(unsolvables,m,mt,mapEqnIncRow,mapIncRowEqn,size,vars,ishared,ass1,ass2,columark,mark,inTVars);
      then
        (outTVars,oMark);
  end match; 
end tearingSystemNew3;

protected function hasnonlinearVars1
  input BackendDAE.AdjacencyMatrixElementEnhanced row;
  output Boolean hasnonlinear;
algorithm
  hasnonlinear := match(row)
    local
      BackendDAE.AdjacencyMatrixElementEnhanced rest;
    case ( {}) then false;
    case ((_,BackendDAE.SOLVABILITY_NONLINEAR())::_)
      then
        true;
    case (_::rest)
      then
        hasnonlinearVars1(rest);
  end match;
end hasnonlinearVars1;

protected function hasnonlinearVars
  input BackendDAE.AdjacencyMatrixElementEnhancedEntry entry;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  output Boolean hasnonlinear;
protected
  Integer r;
  BackendDAE.AdjacencyMatrixElementEnhanced row;
algorithm
  (r,_) := entry;
  row := m[r];
  hasnonlinear := hasnonlinearVars1(row);
end hasnonlinearVars;

protected function sortEqnsSolvabel
"function sortEqnsSolvabel
  author: Frenkel TUD 2012-10
  moves equations with nonlinear or unsolvable parts on the end"
  input BackendDAE.AdjacencyMatrixElementEnhanced queue;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  output BackendDAE.AdjacencyMatrixElementEnhanced nextQeue;
protected
  BackendDAE.AdjacencyMatrixElementEnhanced qnon,qsolv;
algorithm
  (qnon,qsolv) := List.split1OnTrue(queue,hasnonlinearVars,m);
  nextQeue := listAppend(qsolv,qnon);
end sortEqnsSolvabel;

protected function tearingBFS "function tearingBFS
  author: Frenkel TUD 2012-05"
  input BackendDAE.AdjacencyMatrixElementEnhanced queue;
  input BackendDAE.AdjacencyMatrixEnhanced m;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input array<list<Integer>> mapEqnIncRow;
  input array<Integer> mapIncRowEqn;   
  input Integer size;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input array<Integer> columark;
  input Integer mark;
  input BackendDAE.AdjacencyMatrixElementEnhanced nextQeue;
algorithm
  _ := match(queue,m,mt,mapEqnIncRow,mapIncRowEqn,size,ass1,ass2,columark,mark,nextQeue)
    local 
      Integer c,eqnsize,cnonscalar;
      BackendDAE.AdjacencyMatrixElementEnhanced rest,newqueue,rows;
    case ({},_,_,_,_,_,_,_,_,_,{}) then ();
    case ({},_,_,_,_,_,_,_,_,_,_)
      equation
        newqueue = List.removeOnTrue(ass2, isAssignedSaveEnhanced, nextQeue);
        newqueue = sortEqnsSolvabel(newqueue,m);
        //  print("NextQeue:\n" +& stringDelimitList(List.map(List.map(newqueue,Util.tuple21),intString),", ") +& "\n");
        tearingBFS(newqueue,m,mt,mapEqnIncRow,mapIncRowEqn,size,ass1,ass2,columark,mark,{});
      then 
        ();
    case((c,_)::rest,_,_,_,_,_,_,_,_,_,_)
      equation
        //  print("Process Eqn " +& intString(c) +& "\n");
        rows = List.removeOnTrue(ass1, isAssignedSaveEnhanced, m[c]); 
        //_ = arrayUpdate(columark,c,mark);
        cnonscalar = mapIncRowEqn[c];
        eqnsize = listLength(mapEqnIncRow[cnonscalar]);
        //  print("Eqn Size " +& intString(eqnsize) +& "\n");
        //  print("Rows: " +& stringDelimitList(List.map(List.map(rows,Util.tuple21),intString),", ") +& "\n");
        newqueue = tearingBFS1(rows,eqnsize,mapEqnIncRow[cnonscalar],mt,ass1,ass2,columark,mark,nextQeue);
        tearingBFS(rest,m,mt,mapEqnIncRow,mapIncRowEqn,size,ass1,ass2,columark,mark,newqueue);
      then 
        ();
  end match; 
end tearingBFS;

protected function isAssignedSaveEnhanced
"function isAssigned
  author: Frenkel TUD 2012-05"
  input array<Integer> ass;
  input tuple<Integer,BackendDAE.Solvability> inTpl;
  output Boolean outB;
algorithm
  outB := matchcontinue(ass,inTpl)
    local
      Integer i;
    case (_,(i,_))
      equation
        true = intGt(i,0);
      then
        intGt(ass[i],0); 
    else
      true;
  end matchcontinue;
end isAssignedSaveEnhanced;

protected function solvable
  input BackendDAE.Solvability s;
  output Boolean b;
algorithm
  b := match(s)
    case BackendDAE.SOLVABILITY_SOLVED() then true;
    case BackendDAE.SOLVABILITY_CONSTONE() then true;
    case BackendDAE.SOLVABILITY_CONST() then true;
    case BackendDAE.SOLVABILITY_PARAMETER(b=b) then b;
    case BackendDAE.SOLVABILITY_TIMEVARYING(b=b) then false;
    case BackendDAE.SOLVABILITY_NONLINEAR() then false;
    case BackendDAE.SOLVABILITY_UNSOLVABLE() then false;
  end match; 
end solvable;

protected function tearingBFS1 "function tearingBFS1
  author: Frenkel TUD 2012-05"
  input BackendDAE.AdjacencyMatrixElementEnhanced rows;
  input Integer size;
  input list<Integer> c;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input array<Integer> columark;
  input Integer mark;
  input BackendDAE.AdjacencyMatrixElementEnhanced inNextQeue;
  output BackendDAE.AdjacencyMatrixElementEnhanced outNextQeue;
algorithm
  outNextQeue := matchcontinue(rows,size,c,mt,ass1,ass2,columark,mark,inNextQeue)
    local 
    case (_,_,_,_,_,_,_,_,_)
      equation
        true = intEq(listLength(rows),size);
        true = solvableLst(rows);
        //  print("Assign Eqns: " +& stringDelimitList(List.map(c,intString),", ") +& "\n");
      then
        tearingBFS2(rows,c,mt,ass1,ass2,columark,mark,inNextQeue);
    case (_,_,_,_,_,_,_,_,_)
      equation
        true = intEq(listLength(rows),size);
        false = solvableLst(rows);
        //  print("cannot Assign Var" +& intString(r) +& " with Eqn " +& intString(c) +& "\n");
      then 
        inNextQeue;
    else then inNextQeue;
  end matchcontinue; 
end tearingBFS1;

protected function solvableLst
  input BackendDAE.AdjacencyMatrixElementEnhanced rows;
  output Boolean solvable;
algorithm
  solvable := match(rows)
    local 
      Integer r;
      BackendDAE.Solvability s;
      BackendDAE.AdjacencyMatrixElementEnhanced rest;
    case ((r,s)::{}) then solvable(s);   
    case ((r,s)::rest)
      equation
        true = solvable(s);   
      then 
        solvableLst(rest);   
  end match;
end solvableLst;

protected function tearingBFS2 "function tearingBFS1
  author: Frenkel TUD 2012-05"
  input BackendDAE.AdjacencyMatrixElementEnhanced rows;
  input list<Integer> clst;
  input BackendDAE.AdjacencyMatrixTEnhanced mt;
  input array<Integer> ass1; 
  input array<Integer> ass2;
  input array<Integer> columark;
  input Integer mark;
  input BackendDAE.AdjacencyMatrixElementEnhanced inNextQeue;
  output BackendDAE.AdjacencyMatrixElementEnhanced outNextQeue;
algorithm
  outNextQeue := match(rows,clst,mt,ass1,ass2,columark,mark,inNextQeue)
    local 
      Integer r,c;
      list<Integer> ilst;
      BackendDAE.Solvability s;
      BackendDAE.AdjacencyMatrixElementEnhanced rest,vareqns,newqueue;
    case ({},_,_,_,_,_,_,_) then inNextQeue;
    case ((r,s)::rest,c::ilst,_,_,_,_,_,_)
      equation
        //  print("Assign Var " +& intString(r) +& " with Eqn " +& intString(c) +& "\n");
        // assigen 
        _ = arrayUpdate(ass1,r,c);
        _ = arrayUpdate(ass2,c,r);
        vareqns = List.removeOnTrue(ass2, isAssignedSaveEnhanced, mt[r]);  
        //vareqns = List.removeOnTrue((columark,mark), isMarked, vareqns);   
        //markEqns(vareqns,columark,mark);     
        newqueue = listAppend(inNextQeue,vareqns);
      then 
        tearingBFS2(rest,ilst,mt,ass1,ass2,columark,mark,newqueue);
  end match; 
end tearingBFS2;

protected function tearingSystemNew4_1 "function tearingSystemNew4
  author: Frenkel TUD 2012-09"
  input BackendDAE.JacobianType jacType;
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input BackendDAE.EqSystem subsyst;
  input list<Integer> tvars;
  input list<Integer> residual;
  input array<Integer> ass1;
  input array<Integer> ass2;
  input list<list<Integer>> othercomps;
  input list<Integer> eindex;
  input list<Integer> vindx;
  input array<list<Integer>> mapEqnIncRow;
  input array<Integer> mapIncRowEqn;
  input array<Integer> columark;
  input Integer mark;
  output BackendDAE.StrongComponent ocomp;
  output Boolean outRunMatching;
algorithm
  (ocomp,outRunMatching):=
    matchcontinue (jacType,isyst,ishared,subsyst,tvars,residual,ass1,ass2,othercomps,eindex,vindx,mapEqnIncRow,mapIncRowEqn,columark,mark)
    local
      list<Integer> ores,residual1,ovars;
      list<tuple<Integer,list<Integer>>> eqnvartpllst;
      array<Integer> eindxarr,varindxarr;
      Boolean linear;
    case (_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print,"handle torn System\n");
        // map indexes back
        residual1 = List.map1r(residual,arrayGet,mapIncRowEqn);
        residual1 = List.fold2(residual1,uniqueIntLst,mark,columark,{});
        eindxarr = listArray(eindex);
        ores = List.map1r(residual1,arrayGet,eindxarr);
        varindxarr = listArray(vindx);
        ovars = List.map1r(tvars,arrayGet,varindxarr);
        eqnvartpllst = tearingSystemNew4_2(othercomps,ass2,mapIncRowEqn,eindxarr,varindxarr,columark,mark,{});
        linear = getLinearfromJacType(jacType);
      then
        (BackendDAE.TORNSYSTEM(ovars, ores, eqnvartpllst, linear),true);           
    case (_,_,_,_,_,_,_,_,_,_,_,_,_,_,_)
      then
        (BackendDAE.TORNSYSTEM({}, {}, {}, false),false);        
  end matchcontinue;  
end tearingSystemNew4_1;

protected function uniqueIntLst
  input Integer c;
  input Integer mark;
  input array<Integer> markarray;
  input list<Integer> iAcc;
  output list<Integer> oAcc;
algorithm
  oAcc := matchcontinue(c,mark,markarray,iAcc)
    case(_,_,_,_)
      equation
        false = intEq(mark,markarray[c]);
        _ = arrayUpdate(markarray,c,mark);
      then
        c::iAcc;
    else
      then
        iAcc;
  end matchcontinue;
end uniqueIntLst;

protected function tearingSystemNew4_2
  input list<list<Integer>> othercomps;
  input array<Integer> ass2;
  input array<Integer> mapIncRowEqn;
  input array<Integer> eindxarr;
  input array<Integer> varindxarr;
  input array<Integer> columark;
  input Integer mark;  
  input list<tuple<Integer,list<Integer>>> iAcc;
  output list<tuple<Integer,list<Integer>>> oEqnVarTplLst;
algorithm
  oEqnVarTplLst :=
  match (othercomps,ass2,mapIncRowEqn,eindxarr,varindxarr,columark,mark,iAcc)
    local
      list<list<Integer>> rest;
      Integer e,v,c;
      list<Integer> vlst,clst,elst;
    case ({},_,_,_,_,_,_,_) then listReverse(iAcc);
    case ({c}::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        e = eindxarr[e];
        v = ass2[c];
        v = varindxarr[v];
      then
        tearingSystemNew4_2(rest,ass2,mapIncRowEqn,eindxarr,varindxarr,columark,mark,(e,{v})::iAcc);
    case (clst::rest,_,_,_,_,_,_,_)
      equation
        elst = List.map1r(clst,arrayGet,mapIncRowEqn);
        e::{} = List.fold2(elst,uniqueIntLst,mark,columark,{});
        e = eindxarr[e];
        vlst = List.map1r(clst,arrayGet,ass2);
        vlst = List.map1r(vlst,arrayGet,varindxarr);
      then
        tearingSystemNew4_2(rest,ass2,mapIncRowEqn,eindxarr,varindxarr,columark,mark,(e,vlst)::iAcc);
  end match;
end tearingSystemNew4_2;

protected function getLinearfromJacType
  input BackendDAE.JacobianType jacType;
  output Boolean linear;
algorithm
  linear := match(jacType)
    case (BackendDAE.JAC_CONSTANT()) then true;
    case (BackendDAE.JAC_TIME_VARYING()) then true;
    case (BackendDAE.JAC_NONLINEAR()) then false;
    case (BackendDAE.JAC_NO_ANALYTIC()) then false;
  end match;
end getLinearfromJacType;

protected function tearingSystemNew4 "function tearingSystemNew4
  author: Frenkel TUD 2012-05"
  input BackendDAE.JacobianType jacType;
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input BackendDAE.EqSystem subsyst;
  input list<Integer> tvars;
  input list<Integer> residual;
  input array<Integer> ass1;
  input array<Integer> ass2;
  input list<list<Integer>> othercomps;
  input list<Integer> eindex;
  input list<Integer> vindx;   
  input array<list<Integer>> mapEqnIncRow;
  input array<Integer> mapIncRowEqn; 
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
  output Boolean outRunMatching;
algorithm
  (osyst,oshared,outRunMatching):=
    matchcontinue (jacType,isyst,ishared,subsyst,tvars,residual,ass1,ass2,othercomps,eindex,vindx,mapEqnIncRow,mapIncRowEqn)
    local
      list<Integer> ores,residual1,othercomps1;
      BackendDAE.EqSystem syst;
      Integer size,numvars;
      list<BackendDAE.Equation> h0,g0,h,g,eqnslst;
      list<list<BackendDAE.Equation>> derivedEquations,hlst,glst; 
      array<list<BackendDAE.Equation>> derivedEquationsArr;
      list<BackendDAE.Var> k0,pdvarlst,tvarslst;    
      BackendDAE.Variables vars,kvars,sysvars,sysvars1,kvars1;
      BackendDAE.EquationArray eqns,syseqns;
      BackendVarTransform.VariableReplacements repl;
      DAE.FunctionTree functionTree;
      list<DAE.ComponentRef> pdcr_lst,tvarcrefs;
      list<DAE.Exp> tvarexps;
      list<BackendDAE.Var> vlst,states,vlst1;
      array<Boolean> eqnmark;
      BackendDAE.StateSets stateSets;
      HashSet.HashSet ht;

    case (BackendDAE.JAC_TIME_VARYING(),BackendDAE.EQSYSTEM(stateSets=stateSets),BackendDAE.SHARED(knownVars=kvars,functionTree=functionTree),_,_,_,_,_,_,_,_,_,_)
    //case (_,_,BackendDAE.SHARED(knownVars=kvars,functionTree=functionTree),_,_,_,_,_,_,_,_)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print,"handle linear torn System\n");
        size = listLength(vindx);
        eqns = BackendEquation.daeEqns(subsyst);
        vars = BackendVariable.daeVars(subsyst);
        // add temp variables for other vars at point zero (k0)
        // replace tearing vars with zero and other wars with temp variables to get equations for point zero (g(z0,k0)=g0)
        repl = List.fold1(tvars,getZeroTVarReplacements,vars,BackendVarTransform.emptyReplacementsSized(size));
        (k0,repl) = getZeroVarReplacements(othercomps,vars,ass2,mapIncRowEqn,repl,{});
        eqnmark = arrayCreate(arrayLength(ass2),false);
        (g0,othercomps1) = getOtherEquationsPointZero(othercomps,vars,eqns,repl,eqnmark,mapIncRowEqn,{},{});
        Debug.fcall(Flags.TEARING_DUMP, print,"k0:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printVarList,k0);
        Debug.fcall(Flags.TEARING_DUMP, print,"g0:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEquationList,g0);
        // replace tearing vars with zero and other wars with temp variables to get residual equations for point zero (h(z0,k0)=h0)
        residual1 = List.map1r(residual,arrayGet,mapIncRowEqn);
        residual1 = List.unique(residual1);
        h0 = List.map3(residual1,getEquationsPointZero,eqns,repl,vars);
        Debug.fcall(Flags.TEARING_DUMP, print,"h0:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEquationList,h0);
        // calculate dh/dz = derivedEquations 
        tvarcrefs = List.map1(tvars,getTVarCrefs,vars);
        // Prepare all needed variables
        sysvars = BackendVariable.daeVars(isyst);
        sysvars1 = BackendVariable.copyVariables(sysvars);
        kvars1 = BackendVariable.copyVariables(kvars);
        states = BackendVariable.getAllStateVarFromVariables(vars);
        sysvars1 = BackendVariable.deleteVars(vars,sysvars1);
        kvars1 = BackendVariable.mergeVariables(sysvars1, kvars1);
        eqnslst = BackendEquation.equationList(eqns);
        (eqnslst,_) = BackendEquation.traverseBackendDAEExpsEqnList(eqnslst, replaceDerCalls, vars);
        derivedEquations = deriveAll(eqnslst,arrayList(ass2),tvarcrefs,functionTree,BackendVariable.listVar({}),kvars1,BackendVariable.listVar(states),BackendVariable.listVar({}),vars,tvarcrefs,("$WRT",true),{});
        derivedEquationsArr = listArray(derivedEquations);
        glst = List.map1r(othercomps1,arrayGet,derivedEquationsArr);
        hlst = List.map1r(residual1,arrayGet,derivedEquationsArr);
        g = List.flatten(glst);
        // take care that tearing vars not used in relations
        tvarslst = List.map1r(tvars,BackendVariable.getVarAt,vars);
        pdcr_lst = List.map(tvarslst,BackendVariable.varCref);
        ht = HashSet.emptyHashSet();
        ht = List.fold(pdcr_lst,BaseHashSet.add,ht);
        (_,(ht,true)) = BackendEquation.traverseBackendDAEExpsEqnList(g,checkTVarsnoRelations,(ht,true));        
        //pdcr_lst = BackendEquation.equationUnknownCrefs(g,BackendVariable.listVar(listAppend(BackendVariable.varList(sysvars),knvarlst)));
        pdcr_lst = BackendEquation.equationUnknownCrefs(g,BackendVariable.daeVars(isyst),kvars);
        pdvarlst = List.map(pdcr_lst,makePardialDerVar);
        Debug.fcall(Flags.TEARING_DUMP, print,"PartialDerivatives:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printVarList,pdvarlst);
        Debug.fcall(Flags.TEARING_DUMP, print,"dh/dz extra:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEquationList,g);
        tvarexps = List.map2(tvars,getTVarCrefExps,vars,ishared);
        Debug.fcall(Flags.TEARING_DUMP, print,"TVars: ");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debuglst,(tvarexps,ExpressionDump.printExpStr,", ","\n")); 
        //  print("dh/dz:\n");
        //  BackendDump.printEquationList(List.flatten(hlst));
        h = generateHEquations(hlst,tvarexps,h0,{});
        Debug.fcall(Flags.TEARING_DUMP, print,"dh/dz*z=-h0:\n");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEquationList,h);
        // check if all tearing vars part of the system
        vlst = List.map1r(tvars,BackendVariable.getVarAt,vars);
        vlst1 = BackendEquation.equationsLstVars(eqnslst, BackendVariable.listVar1(vlst));
        numvars = listLength(vlst1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debugStrIntStr,("Found ",numvars," Tearing Vars in the Residual Equations\n"));
        true = intEq(listLength(tvars),numvars);
        // replace new residual equations in original system
        syseqns = BackendEquation.daeEqns(isyst);
        Debug.fcall2(Flags.TEARING_DUMP, BackendDump.dumpEqSystem, isyst, "dump original system");
        // all additional vars and equations
        sysvars = BackendVariable.addVars(k0,sysvars);
        sysvars = BackendVariable.addVars(pdvarlst,sysvars);
        syseqns = BackendEquation.addEquations(g0, syseqns);
        syseqns = BackendEquation.addEquations(g, syseqns);
        // replace new residual equations in original system
        ores = List.map1r(residual1,arrayGet,listArray(eindex));
        syseqns = replaceHEquationsinSystem(ores,h,syseqns);
        syst = BackendDAE.EQSYSTEM(sysvars,syseqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);
        //  BackendDump.printEqSystem(syst);
        Debug.fcall2(Flags.TEARING_DUMP, BackendDump.dumpEqSystem, syst, "dump original replaced system");
      then
        (syst,ishared,true);
  
    case (_,_,_,_,_,_,_,_,_,_,_,_,_)
      equation
        Debug.fcall(Flags.TEARING_DUMP, print,"handle torn System\n");
        // solve other equations for other vars
        size = listLength(eindex);
        // do not use it if more than 50 equations there, 
        // this will be fixed if it is possible to save the information of tearing variables
        // and residual equations for code generation, than it is not necessary to solve all the other 
        // equations and replace the other variables in the residual equations
        true = intLt(size,50);
        eqns = BackendEquation.daeEqns(subsyst);
        vars = BackendVariable.daeVars(subsyst);
        // take care that tearing vars not used in relations until tearing information is saved for code generation and other equations needs not to be solved and
        // solution inserted in residual equation
        k0 = List.map1r(tvars,BackendVariable.getVarAt,vars);
        pdcr_lst = List.map(k0,BackendVariable.varCref);
        ht = HashSet.emptyHashSet();
        ht = List.fold(pdcr_lst,BaseHashSet.add,ht);
        ((ht,true)) = BackendDAEUtil.traverseBackendDAEExpsEqns(eqns,checkTVarsnoRelations,(ht,true));
        
        tvarexps = List.map2(tvars,getTVarCrefExps,vars,ishared);
        Debug.fcall(Flags.TEARING_DUMP, print,"TVars: ");
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debuglst,(tvarexps,ExpressionDump.printExpStr,", ","\nOther Equations:\n"));        
        (eqns,repl,k0) = solveOtherEquations(othercomps,eqns,vars,ass2,mapIncRowEqn,ishared,BackendVarTransform.emptyReplacementsSized(size),{});
        // replace other vars in residual equations with there expression, use reverse order from othercomps
        Debug.fcall(Flags.TEARING_DUMP, print,"Residual Equations:\n");
        residual1 = List.map1r(residual,arrayGet,mapIncRowEqn);
        residual1 = List.unique(residual1);         
        eqns = List.fold2(residual1,replaceOtherVarinResidualEqns,repl,BackendVariable.listVar1(k0),eqns);
        // check if all tearing vars part of the system
        vlst = List.map1r(tvars,BackendVariable.getVarAt,vars);
        eqnslst = BackendEquation.getEqns(residual1,eqns);
        vlst1 = BackendEquation.equationsLstVars(eqnslst, BackendVariable.listVar1(vlst));
        numvars = listLength(vlst1);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debugStrIntStr,("Found ",numvars," Tearing Vars in the Residual Equations\n"));
        true = intEq(listLength(tvars),numvars);       
        // replace new residual equations in original system
        Debug.fcall2(Flags.TEARING_DUMP, BackendDump.dumpEqSystem, isyst, "dump original system");
        syst = replaceTornEquationsinSystem(residual1,listArray(eindex),eqns,isyst);
        Debug.fcall2(Flags.TEARING_DUMP, BackendDump.dumpEqSystem, syst, "dump original replaced system");        
      then
        (syst,ishared,true);           
    case (_,_,_,_,_,_,_,_,_,_,_,_,_)
      then
        (isyst,ishared,false);        
  end matchcontinue;  
end tearingSystemNew4;

protected function checkTVarsnoRelations
  input tuple<DAE.Exp, tuple<HashSet.HashSet,Boolean>> inTpl;
  output tuple<DAE.Exp, tuple<HashSet.HashSet,Boolean>> outTpl;
algorithm
  outTpl :=
  match inTpl
    local  
      DAE.Exp exp;
      HashSet.HashSet ht;
      Boolean b;
    case ((exp,(ht,true)))
      equation
         ((_,(_,b))) = Expression.traverseExpTopDown(exp,checkTVarsnoRelationsExp,(ht,true));
       then
        ((exp,(ht,b)));
    case inTpl then inTpl;
  end match;
end checkTVarsnoRelations;

protected function checkTVarsnoRelationsExp
  input tuple<DAE.Exp, tuple<HashSet.HashSet,Boolean>> inTuple;
  output tuple<DAE.Exp, Boolean, tuple<HashSet.HashSet,Boolean>> outTuple;
algorithm
  outTuple := match(inTuple)
    local
      DAE.Exp e,ife,e1,e2,e3;
      HashSet.HashSet ht;
      Boolean b;
      
    case ((e as DAE.CALL(path = Absyn.IDENT(name = "pre")),(ht,b))) then ((e,false,(ht,b)));     

    case ((e as DAE.IFEXP(expCond=e1, expThen=e2, expElse=e3),(ht,true)))
      equation
        ((_,(_,b))) = Expression.traverseExpTopDown(e1,checkTVarsnoRelationsExp1,(ht,true));  
        ((_,(_,b))) = Expression.traverseExpTopDown(e2,checkTVarsnoRelationsExp,(ht,b));  
        ((_,(_,b))) = Expression.traverseExpTopDown(e3,checkTVarsnoRelationsExp,(ht,b));
      then ((e, b, (ht,b)));

    case ((e as DAE.LBINARY(exp1=e1, exp2=e2),(ht,true)))
      equation
        ((_,(_,b))) = Expression.traverseExpTopDown(e1,checkTVarsnoRelationsExp1,(ht,true));  
        ((_,(_,b))) = Expression.traverseExpTopDown(e2,checkTVarsnoRelationsExp1,(ht,b));  
      then ((e, b, (ht,b)));

    case ((e as DAE.RELATION(exp1=e1, exp2=e2),(ht,true)))
      equation
        ((_,(_,b))) = Expression.traverseExpTopDown(e1,checkTVarsnoRelationsExp1,(ht,true));  
        ((_,(_,b))) = Expression.traverseExpTopDown(e2,checkTVarsnoRelationsExp1,(ht,b));  
      then ((e, b, (ht,b)));

    case ((e as DAE.LUNARY(exp=e1),(ht,true)))
      equation
        ((_,(_,b))) = Expression.traverseExpTopDown(e1,checkTVarsnoRelationsExp1,(ht,true));  
      then ((e, b, (ht,b)));
    
    case ((e,(ht,b))) then ((e,b,(ht,b)));
  end match;
end checkTVarsnoRelationsExp;

protected function checkTVarsnoRelationsExp1
  input tuple<DAE.Exp, tuple<HashSet.HashSet,Boolean>> inTuple;
  output tuple<DAE.Exp, Boolean, tuple<HashSet.HashSet,Boolean>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e,e1;
      DAE.ComponentRef cr;
      HashSet.HashSet ht;
      list<DAE.Var> varLst;
      list<DAE.Exp> expl;
      Boolean b,b1;
  
    case ((e as DAE.CALL(path = Absyn.IDENT(name = "pre")),(ht,b))) then ((e,false,(ht,b)));     
    
    // special case for time, it is never part of the equation system  
    case ((e as DAE.CREF(componentRef = DAE.CREF_IDENT(ident="time")),(ht,true)))
      then ((e, false, (ht,true)));
    
    // Special Case for Records
    case ((e as DAE.CREF(componentRef = cr,ty= DAE.T_COMPLEX(varLst=varLst,complexClassType=ClassInf.RECORD(_))),(ht,true)))
      equation
        expl = List.map1(varLst,Expression.generateCrefsExpFromExpVar,cr);
        ((_,(ht,b))) = Expression.traverseExpListTopDown(expl,checkTVarsnoRelationsExp1,(ht,true));
      then
        ((e,false,(ht,b)));

    // Special Case for Arrays
    case ((e as DAE.CREF(ty = DAE.T_ARRAY(ty=_)),(ht,true)))
      equation
        ((e1,(_,true))) = BackendDAEUtil.extendArrExp((e,(NONE(),false)));
        ((_,(ht,b))) = Expression.traverseExpTopDown(e1,checkTVarsnoRelationsExp1,(ht,true));
      then
        ((e,false, (ht,b)));
    
    // case for functionpointers    
    case ((e as DAE.CREF(ty=DAE.T_FUNCTION_REFERENCE_FUNC(builtin=_)),(ht,b)))
      then
        ((e,false, (ht,b)));

    // already there
    case ((e as DAE.CREF(componentRef = cr),(ht,true)))
      equation
         b1 = BaseHashSet.has(cr, ht);
         b1 = not b1;
      then
        ((e, false,(ht,b1)));

    case ((e,(ht,b))) then ((e,b,(ht,b)));
  end matchcontinue;
end checkTVarsnoRelationsExp1;

protected function replaceHEquationsinSystem
  input list<Integer> eindx;
  input list<BackendDAE.Equation> HEqns;
  input BackendDAE.EquationArray iEqns;
  output BackendDAE.EquationArray oEqns;
algorithm
  oEqns := match(eindx,HEqns,iEqns)
    local
      Integer e;
      list<Integer> rest;
      BackendDAE.Equation eqn;
      list<BackendDAE.Equation> eqnlst;
      BackendDAE.EquationArray eqns;
    case ({},_,_) then iEqns;
    case (e::rest,eqn::eqnlst,_)
      equation
        eqns = BackendEquation.equationSetnth(iEqns, e-1, eqn);
      then
        replaceHEquationsinSystem(rest,eqnlst,eqns);
  end match;
end replaceHEquationsinSystem;

protected function equationToExp
  input BackendDAE.Equation Eqn;
  output DAE.Exp outExp;
algorithm
  outExp := match(Eqn)
    local
      DAE.Exp e1,e2;
      DAE.ComponentRef cr;
    case BackendDAE.EQUATION(exp = e1,scalar = e2) then Expression.expSub(e1,e2);    
    case BackendDAE.SOLVED_EQUATION(componentRef = cr,exp = e2) then Expression.expSub(Expression.crefExp(cr),e2);    
    case BackendDAE.RESIDUAL_EQUATION(exp = e1) then e1;   
    else
      equation
       BackendDump.debugStrEqnStr(("Cannot Handle Eqn",Eqn,"\n"));
      then
        fail(); 
  end match;
end equationToExp;

protected function generateHEquations
  input list<list<BackendDAE.Equation>> HEqns;
  input list<DAE.Exp> tvarcrefs;
  input list<BackendDAE.Equation> HZeroEqns;
  input list<BackendDAE.Equation> iEqns;
  output list<BackendDAE.Equation> oEqns;
algorithm
  oEqns := match(HEqns,tvarcrefs,HZeroEqns,iEqns)
    local
     list<list<BackendDAE.Equation>> heqns;
     list<BackendDAE.Equation> eqns,hzeroeqns;
     BackendDAE.Equation eqn;
     list<DAE.Exp> explst;
     DAE.Exp e1,e2;
     DAE.ElementSource source;
     list<Integer> dimSize;
     Integer ntvars,dim;
     list<list<DAE.Exp>> explstlst;
     DAE.Type ty;
    case ({},_,_,_) then listReverse(iEqns);
    case (eqns::heqns,_,(eqn as BackendDAE.ARRAY_EQUATION(dimSize=dimSize,left=e1,right=e2,source=source))::hzeroeqns,_)
      equation
        e2 = Expression.expSub(e1, e2);
        e2 = Expression.negate(e2);
        explst = List.map(eqns,equationToExp);
        ntvars = listLength(tvarcrefs);
        explstlst = List.partition(explst,ntvars);
        explst = List.map1(explstlst, generateHEquations1,tvarcrefs);
        // TODO: Implement also for more than one dimensional arrays
        dim::{} = dimSize;
        ty = Expression.typeof(e2);
        e1 = DAE.ARRAY(ty, true, explst);
      then
        generateHEquations(heqns,tvarcrefs,hzeroeqns,BackendDAE.ARRAY_EQUATION(dimSize,e1,e2,source,false)::iEqns);      
    case (eqns::heqns,_,eqn::hzeroeqns,_)
      equation
        explst = List.map(eqns,equationToExp);
        explst = List.threadMap(explst,tvarcrefs,Expression.expMul);
        e1 = Expression.makeSum(explst);
        e2 = equationToExp(eqn);
        e2 = Expression.negate(e2);
        source = BackendEquation.equationSource(eqn);
      then
        generateHEquations(heqns,tvarcrefs,hzeroeqns,BackendDAE.EQUATION(e1,e2,source,false)::iEqns);
  end match;
end generateHEquations;

protected function generateHEquations1
  input list<DAE.Exp> explst;
  input list<DAE.Exp> tvarcrefs;
  output DAE.Exp e;
protected
  list<DAE.Exp> explst1;
algorithm
  explst1 := List.threadMap(explst,tvarcrefs,Expression.expMul);
  e := Expression.makeSum(explst1);
end generateHEquations1;

protected function getOtherDerivedEquations
  input list<list<Integer>> othercomps; 
  input array<list<BackendDAE.Equation>> derivedEquations;
  input list<list<BackendDAE.Equation>> iOtherEqns;
  output list<list<BackendDAE.Equation>> oOtherEqns;
algorithm
  oOtherEqns :=
  matchcontinue (othercomps,derivedEquations,iOtherEqns)
    local
      Integer c;
      list<list<Integer>> rest;
      list<BackendDAE.Equation> g;
    case ({},_,_) then listReverse(iOtherEqns);
    case ({c}::rest,_,_)
      equation
        g = derivedEquations[c];
      then
        getOtherDerivedEquations(rest,derivedEquations,g::iOtherEqns); 
  end matchcontinue;  
end getOtherDerivedEquations;

protected function makePardialDerVar
  input DAE.ComponentRef cr;
  output BackendDAE.Var v;
algorithm
  v := BackendDAE.VAR(cr,BackendDAE.VARIABLE(),DAE.BIDIR(),DAE.NON_PARALLEL(),DAE.T_REAL_DEFAULT,NONE(),NONE(),{},DAE.emptyElementSource,NONE(),NONE(),DAE.NON_CONNECTOR());
end makePardialDerVar;

protected function getTVarCrefs "function getTVarCrefs
  author: Frenkel TUD 2011-05
  return cref of var v from vararray"
  input Integer v;
  input BackendDAE.Variables inVars;
  output DAE.ComponentRef cr;
protected
  BackendDAE.Var var;
algorithm
  var := BackendVariable.getVarAt(inVars, v);
  cr := BackendVariable.varCref(var);
  cr := Debug.bcallret1(BackendVariable.isStateVar(var), ComponentReference.crefPrefixDer, cr, cr);
end getTVarCrefs;

protected function getTVarCrefExps "function getTVarCrefExps
  author: Frenkel TUD 2011-05
  return cref exp of var v from vararray"
  input Integer v;
  input BackendDAE.Variables inVars;
  input BackendDAE.Shared ishared;
  output DAE.Exp exp;
protected
  BackendDAE.Var var;
  DAE.ComponentRef cr;
algorithm
  var := BackendVariable.getVarAt(inVars, v);
  cr := BackendVariable.varCref(var);
  exp := Expression.crefExp(cr);
  exp := Debug.bcallret2(BackendVariable.isStateVar(var), Derive.differentiateExpTime, exp, (inVars,ishared), exp);
end getTVarCrefExps;

protected function getZeroTVarReplacements "function getZeroTVarReplacements
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input Integer v;
  input BackendDAE.Variables inVars;
  input BackendVarTransform.VariableReplacements inRepl;
  output BackendVarTransform.VariableReplacements outRepl;
protected
  DAE.ComponentRef cr;
  BackendDAE.Var var;
algorithm
  var := BackendVariable.getVarAt(inVars, v);
  cr := BackendVariable.varCref(var);
  cr := Debug.bcallret1(BackendVariable.isStateVar(var), ComponentReference.crefPrefixDer, cr, cr);
  outRepl := BackendVarTransform.addReplacement(inRepl,cr,DAE.RCONST(0.0),NONE());
end getZeroTVarReplacements;

protected function getEquationsPointZero "function getEquationsPointZero
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input Integer index;
  input BackendDAE.EquationArray inEqns;
  input BackendVarTransform.VariableReplacements inRepl;
  input BackendDAE.Variables inVars;
  output BackendDAE.Equation outEqn;
algorithm
  outEqn := BackendDAEUtil.equationNth(inEqns, index-1);
  (outEqn,_) := BackendEquation.traverseBackendDAEExpsEqn(outEqn,replaceDerCalls,inVars);
  (outEqn::_,_) := BackendVarTransform.replaceEquations({outEqn}, inRepl,NONE());
end getEquationsPointZero;

protected function getZeroVarReplacements "function getZeroVarReplacements
  author: Frenkel TUD 2012-07
  add for the other variables the zero var replacement cr->$ZERO.cr."
  input list<list<Integer>> othercomps;
  input BackendDAE.Variables inVars;
  input array<Integer> ass2;
  input array<Integer> mapIncRowEqn;
  input BackendVarTransform.VariableReplacements inRepl;
  input list<BackendDAE.Var> inVarLst;
  output list<BackendDAE.Var> outVarLst;
  output BackendVarTransform.VariableReplacements outRepl;
algorithm
  (outVarLst,outRepl) :=
  match (othercomps,inVars,ass2,mapIncRowEqn,inRepl,inVarLst)
    local
      list<list<Integer>> rest;
      Integer c,e;
      list<Integer> clst;
      BackendVarTransform.VariableReplacements repl;
      list<BackendDAE.Var> varLst;
    case ({},_,_,_,_,_) then (inVarLst,inRepl);
    case ({c}::rest,_,_,_,_,_)
      equation
        (varLst,repl) = getZeroVarReplacements1({c},inVars,ass2,mapIncRowEqn,inRepl,inVarLst);
        (varLst,repl) = getZeroVarReplacements(rest,inVars,ass2,mapIncRowEqn,repl,varLst);
      then
        (varLst,repl);
    case ((c::clst)::rest,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        true = getZeroVarReplacements2(e,clst,mapIncRowEqn);
        (varLst,repl) = getZeroVarReplacements1(c::clst,inVars,ass2,mapIncRowEqn,inRepl,inVarLst);
        (varLst,repl) = getZeroVarReplacements(rest,inVars,ass2,mapIncRowEqn,repl,varLst);
      then
        (varLst,repl);        
  end match;
end getZeroVarReplacements;

protected function getZeroVarReplacements2
  input Integer e;
  input list<Integer> clst;
  input array<Integer> mapIncRowEqn;
  output Boolean b;
algorithm
  b := match(e,clst,mapIncRowEqn)
    local 
      Integer ce;
      list<Integer> rest;
    case(_,ce::{},_) 
      then intEq(e,mapIncRowEqn[ce]);
    case(_,ce::rest,_)
      equation
        true = intEq(e,mapIncRowEqn[ce]);
      then
        getZeroVarReplacements2(e,rest,mapIncRowEqn);
  end match;
end getZeroVarReplacements2;


protected function getZeroVarReplacements1 "function getZeroVarReplacements1
  author: Frenkel TUD 2012-07
  add for the other variables the zero var replacement cr->$ZERO.cr."
  input list<Integer> clst;
  input BackendDAE.Variables inVars;
  input array<Integer> ass2;
  input array<Integer> mapIncRowEqn;
  input BackendVarTransform.VariableReplacements inRepl;
  input list<BackendDAE.Var> inVarLst;
  output list<BackendDAE.Var> outVarLst;
  output BackendVarTransform.VariableReplacements outRepl;
algorithm
  (outVarLst,outRepl) :=
  match (clst,inVars,ass2,mapIncRowEqn,inRepl,inVarLst)
    local
      list<Integer> rest;
      Integer c,v;
      DAE.Exp varexp;
      DAE.ComponentRef cr,cr1;
      BackendVarTransform.VariableReplacements repl;
      list<BackendDAE.Var> varLst;
      BackendDAE.Var var;
      DAE.Type ty;
    case ({},_,_,_,_,_) 
      then 
        (inVarLst,inRepl);
    case (c::rest,_,_,_,_,_)
      equation
        v = ass2[c];
        var = BackendVariable.getVarAt(inVars, v);
        cr = BackendVariable.varCref(var);
        cr = Debug.bcallret1(BackendVariable.isStateVar(var), ComponentReference.crefPrefixDer, cr, cr);
        cr1 = ComponentReference.makeCrefQual("$ZERO",DAE.T_COMPLEX_DEFAULT,{},cr);
        cr1 = ComponentReference.replaceSubsWithString(cr1);
        varexp = Expression.crefExp(cr1);
        repl = BackendVarTransform.addReplacement(inRepl,cr,varexp,NONE());
        ty = ComponentReference.crefLastType(cr1);
        var = BackendDAE.VAR(cr1,BackendDAE.VARIABLE(),DAE.BIDIR(),DAE.NON_PARALLEL(),ty,NONE(),NONE(),{},DAE.emptyElementSource,NONE(),NONE(),DAE.NON_CONNECTOR());
        //var = BackendVariable.copyVarNewName(cr1,var);
        //var = BackendVariable.setVarKind(var, BackendDAE.VARIABLE());
        //var = BackendVariable.setVarAttributes(var, NONE());
        (varLst,repl) = getZeroVarReplacements1(rest,inVars,ass2,mapIncRowEqn,repl,var::inVarLst);
      then
        (varLst,repl);
  end match;
end getZeroVarReplacements1;

protected function getOtherEquationsPointZero "function getOtherEquationsPointZero
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input list<list<Integer>> othercomps;
  input BackendDAE.Variables inVars;
  input BackendDAE.EquationArray inEqns;
  input BackendVarTransform.VariableReplacements inRepl;
  input array<Boolean> eqnmark;
  input array<Integer> mapIncRowEqn;  
  input list<BackendDAE.Equation> inEqsLst;
  input list<Integer> inComps;
  output list<BackendDAE.Equation> outEqsLst;
  output list<Integer> outComps;
algorithm
  (outEqsLst,outComps) :=
  matchcontinue (othercomps,inVars,inEqns,inRepl,eqnmark,mapIncRowEqn,inEqsLst,inComps)
    local
      list<list<Integer>> rest;
      Integer e,c;
      BackendDAE.Equation eqn;
      list<Integer> clst;
    case ({},_,_,_,_,_,_,_) then (listReverse(inEqsLst),listReverse(inComps));
    case ({c}::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        false = eqnmark[e];
        _ = arrayUpdate(eqnmark,e,true);
        eqn = BackendDAEUtil.equationNth(inEqns, e-1);
        (eqn,_) = BackendEquation.traverseBackendDAEExpsEqn(eqn,replaceDerCalls,inVars);
        (eqn::_,_) = BackendVarTransform.replaceEquations({eqn}, inRepl,SOME(BackendVarTransform.skipPreOperator));
       (outEqsLst,outComps) = getOtherEquationsPointZero(rest,inVars,inEqns,inRepl,eqnmark,mapIncRowEqn,eqn::inEqsLst,e::inComps);
      then
        (outEqsLst,outComps);
    case ((c::clst)::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        true = getZeroVarReplacements2(e,clst,mapIncRowEqn);        
        false = eqnmark[e];
        _ = arrayUpdate(eqnmark,e,true);
        eqn = BackendDAEUtil.equationNth(inEqns, e-1);
        (eqn,_) = BackendEquation.traverseBackendDAEExpsEqn(eqn,replaceDerCalls,inVars);
        (eqn::_,_) = BackendVarTransform.replaceEquations({eqn}, inRepl,SOME(BackendVarTransform.skipPreOperator));
       (outEqsLst,outComps) = getOtherEquationsPointZero(rest,inVars,inEqns,inRepl,eqnmark,mapIncRowEqn,eqn::inEqsLst,e::inComps);
      then
        (outEqsLst,outComps);        
    case ({c}::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        true = eqnmark[e];
        (outEqsLst,outComps) = getOtherEquationsPointZero(rest,inVars,inEqns,inRepl,eqnmark,mapIncRowEqn,inEqsLst,inComps);
      then
        (outEqsLst,outComps);        
    case ((c::clst)::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        true = eqnmark[e];
        (outEqsLst,outComps) = getOtherEquationsPointZero(rest,inVars,inEqns,inRepl,eqnmark,mapIncRowEqn,inEqsLst,inComps);
      then
        (outEqsLst,outComps);        
  end matchcontinue;
end getOtherEquationsPointZero;


protected function replaceDerCalls
  input tuple<DAE.Exp, BackendDAE.Variables> inTpl;
  output tuple<DAE.Exp, BackendDAE.Variables> outTpl;
algorithm
  outTpl :=
  matchcontinue inTpl
    local  
      DAE.Exp exp;
      BackendDAE.Variables vars;
    case ((exp,vars))
      equation
         ((exp,_)) = Expression.traverseExp(exp,replaceDerCallsExp,vars);
       then
        ((exp,vars));
    case inTpl then inTpl;
  end matchcontinue;
end replaceDerCalls;

protected function replaceDerCallsExp
  input tuple<DAE.Exp, BackendDAE.Variables> inTuple;
  output tuple<DAE.Exp, BackendDAE.Variables> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e;
      BackendDAE.Variables vars;
      DAE.ComponentRef cr;
   
     case ((DAE.CALL(path = Absyn.IDENT(name = "der"),expLst = {DAE.CREF(componentRef = cr)}),vars))
      equation
        (_::{},_) = BackendVariable.getVar(cr,vars);
        cr = ComponentReference.crefPrefixDer(cr);
        e = Expression.crefExp(cr);
      then
        ((e, vars));
    
    case inTuple then inTuple;
  end matchcontinue;
end replaceDerCallsExp;

protected function solveOtherEquations "function solveOtherEquations
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input list<list<Integer>> othercomps;
  input BackendDAE.EquationArray inEqns;
  input BackendDAE.Variables inVars;
  input array<Integer> ass2;
  input array<Integer> mapIncRowEqn;
  input BackendDAE.Shared ishared;
  input BackendVarTransform.VariableReplacements inRepl;
  input list<BackendDAE.Var> iOtherVars;
  output BackendDAE.EquationArray outEqns;
  output BackendVarTransform.VariableReplacements outRepl;
  output list<BackendDAE.Var> oOtherVars;
algorithm
  (outEqns,outRepl,oOtherVars) :=
  match (othercomps,inEqns,inVars,ass2,mapIncRowEqn,ishared,inRepl,iOtherVars)
    local
      list<list<Integer>> rest;
      BackendDAE.EquationArray eqns;
      Integer v,c,e;
      DAE.Exp e1,e2,varexp,expr;
      DAE.ComponentRef cr,dcr;
      DAE.ElementSource source;
      BackendVarTransform.VariableReplacements repl;
      BackendDAE.Var var;
      list<BackendDAE.Var> otherVars,varlst;
      list<Integer> clst,ds,vlst;
      list<DAE.Exp> explst1,explst2;
      BackendDAE.Equation eqn;
      list<Option<Integer>> ad;
      list<list<DAE.Subscript>> subslst;
      Boolean diffed;
    case ({},_,_,_,_,_,_,_) then (inEqns,inRepl,iOtherVars);
    case ({c}::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        (eqn as BackendDAE.EQUATION(e1,e2,source,diffed)) = BackendDAEUtil.equationNth(inEqns, e-1);
        v = ass2[c];
        (var as BackendDAE.VAR(varName=cr)) = BackendVariable.getVarAt(inVars, v);
        varexp = Expression.crefExp(cr);
        varexp = Debug.bcallret1(BackendVariable.isStateVar(var), Expression.expDer, varexp, varexp);
        (expr,{}) = ExpressionSolve.solve(e1, e2, varexp);
        eqns = BackendEquation.equationSetnth(inEqns,e-1,BackendDAE.EQUATION(expr,varexp,source,diffed));
        dcr = Debug.bcallret1(BackendVariable.isStateVar(var), ComponentReference.crefPrefixDer, cr, cr);
        repl = BackendVarTransform.addReplacement(inRepl,dcr,expr,SOME(BackendVarTransform.skipPreOperator));
        repl = Debug.bcallret3(BackendVariable.isStateVar(var), BackendVarTransform.addDerConstRepl, cr, expr, repl, repl);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debugStrCrefStrExpStr,("",dcr," := ",expr,"\n"));
        (eqns,repl,otherVars) = solveOtherEquations(rest,eqns,inVars,ass2,mapIncRowEqn,ishared,repl,var::iOtherVars);
      then
        (eqns,repl,otherVars);
    case ((c::clst)::rest,_,_,_,_,_,_,_)
      equation
        e = mapIncRowEqn[c];
        true = getZeroVarReplacements2(e,clst,mapIncRowEqn);        
        (eqn as BackendDAE.ARRAY_EQUATION(dimSize=ds,left=e1,right=e2,source=source)) = BackendDAEUtil.equationNth(inEqns, e-1);
        vlst = List.map1r(c::clst,arrayGet,ass2);
        varlst = List.map1r(vlst,BackendVariable.getVarAt,inVars);
        ad = List.map(ds,Util.makeOption);
        subslst = BackendDAEUtil.arrayDimensionsToRange(ad);
        subslst = BackendDAEUtil.rangesToSubscripts(subslst);
        explst1 = List.map1r(subslst,Expression.applyExpSubscripts,e1);
        explst1 = ExpressionSimplify.simplifyList(explst1, {});
        explst2 = List.map1r(subslst,Expression.applyExpSubscripts,e2);
        explst2 = ExpressionSimplify.simplifyList(explst2, {});
        (repl,otherVars) = solveOtherEquations1(explst1,explst2,varlst,inVars,ishared,inRepl,iOtherVars);
        (eqns,repl,otherVars) = solveOtherEquations(rest,inEqns,inVars,ass2,mapIncRowEqn,ishared,repl,otherVars);
      then
        (eqns,repl,otherVars);       

  end match;
end solveOtherEquations;

protected function solveOtherEquations1 "function solveOtherEquations
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input list<DAE.Exp> iExps1;
  input list<DAE.Exp> iExps2;
  input list<BackendDAE.Var> iVars;
  input BackendDAE.Variables inVars;
  input BackendDAE.Shared ishared;  
  input BackendVarTransform.VariableReplacements inRepl;
  input list<BackendDAE.Var> iOtherVars;
  output BackendVarTransform.VariableReplacements outRepl;
  output list<BackendDAE.Var> oOtherVars;
algorithm
  (outRepl,oOtherVars) :=
  match (iExps1,iExps2,iVars,inVars,ishared,inRepl,iOtherVars)
    local
      DAE.Exp e1,e2,varexp,expr;
      DAE.ComponentRef cr,dcr;
      BackendVarTransform.VariableReplacements repl;
      BackendDAE.Var var;
      list<BackendDAE.Var> otherVars,rest;
      list<DAE.Exp> explst1,explst2;
    case ({},_,_,_,_,_,_) then (inRepl,iOtherVars);
    case (e1::explst1,e2::explst2,(var as BackendDAE.VAR(varName=cr))::rest,_,_,_,_)
      equation
        varexp = Expression.crefExp(cr);
        varexp = Debug.bcallret1(BackendVariable.isStateVar(var), Expression.expDer, varexp, varexp);
        (expr,{}) = ExpressionSolve.solve(e1, e2, varexp);
        dcr = Debug.bcallret1(BackendVariable.isStateVar(var), ComponentReference.crefPrefixDer, cr, cr);
        repl = BackendVarTransform.addReplacement(inRepl,dcr,expr,SOME(BackendVarTransform.skipPreOperator));
        repl = Debug.bcallret3(BackendVariable.isStateVar(var), BackendVarTransform.addDerConstRepl, cr, expr, repl, repl);
        Debug.fcall(Flags.TEARING_DUMP, BackendDump.debugStrCrefStrExpStr,("",dcr," := ",expr,"\n"));
        (repl,otherVars) = solveOtherEquations1(explst1,explst2,rest,inVars,ishared,repl,var::iOtherVars);
      then
        (repl,otherVars);
  end match;
end solveOtherEquations1;

protected function replaceOtherVarinResidualEqns "function replaceOtherVarinResidualEqns
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input Integer c;
  input BackendVarTransform.VariableReplacements inRepl;
  input BackendDAE.Variables inOtherVars;
  input BackendDAE.EquationArray inEqns;
  output BackendDAE.EquationArray outEqns;
protected
  BackendDAE.Equation eqn;
algorithm
  eqn := BackendDAEUtil.equationNth(inEqns, c-1);
  (eqn,_) := BackendEquation.traverseBackendDAEExpsEqn(eqn,replaceDerCalls,inOtherVars);
  (eqn::_,_) := BackendVarTransform.replaceEquations({eqn}, inRepl,SOME(BackendVarTransform.skipPreOperator));
  outEqns := BackendEquation.equationSetnth(inEqns,c-1,eqn);
  Debug.fcall(Flags.TEARING_DUMP, BackendDump.printEquation,eqn);
end replaceOtherVarinResidualEqns;

protected function replaceTornEquationsinSystem "function setTornEquationsinSystem
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input list<Integer> residual;
  input array<Integer> eindxarray;
  input BackendDAE.EquationArray inEqns;
  input BackendDAE.EqSystem isyst;
  output BackendDAE.EqSystem osyst;
protected
   BackendDAE.EqSystem syst;
   BackendDAE.Variables vars;
   BackendDAE.EquationArray eqns;
   BackendDAE.StateSets stateSets;
algorithm
 BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets) := isyst;
 eqns := replaceTornEquationsinSystem1(residual,eindxarray,inEqns,eqns);
 osyst := BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);  
end replaceTornEquationsinSystem;

protected function replaceTornEquationsinSystem1 "function setTornEquationsinSystem
  author: Frenkel TUD 2011-05
  try to solve the equations"
  input list<Integer> residual;
  input array<Integer> eindxarray;
  input BackendDAE.EquationArray inEqns;
  input BackendDAE.EquationArray isyst;
  output BackendDAE.EquationArray osyst;
algorithm
  osyst := match (residual,eindxarray,inEqns,isyst)
    local
      Integer c,index;
      list<Integer> rest;
      BackendDAE.Equation eqn;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray syst;
    case ({},_,_,_) then isyst;
    case (c::rest,_,_,_)
      equation
        index = eindxarray[c];
        eqn = BackendDAEUtil.equationNth(inEqns, c-1);
        syst = BackendEquation.equationSetnth(isyst,index-1,eqn);
      then
        replaceTornEquationsinSystem1(rest,eindxarray,inEqns,syst);
  end match;
end replaceTornEquationsinSystem1;




/*
 * countOperations
 *
 */
public function countOperations "function countOperations
  author: Frenkel TUD 2011-05"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,countOperations0,false);
end countOperations;

protected function countOperations0 "function countOperations0
  author: Frenkel TUD 2011-05"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) :=
    match(isyst,sharedChanged)
    local
      BackendDAE.Shared shared;
      Boolean b;
      Integer i1,i2,i3;
      BackendDAE.StrongComponents comps;
      
    case (BackendDAE.EQSYSTEM(matching=BackendDAE.MATCHING(comps=comps)),(shared, b))
      equation
        ((i1,i2,i3)) = countOperationstraverseComps(comps,isyst,shared,(0,0,0));
        print("Add Operations: " +& intString(i1) +& "\n");
        print("Mul Operations: " +& intString(i2) +& "\n");
        print("Oth Operations: " +& intString(i3) +& "\n");
      then
        (isyst,(shared,b));
  end match;
end countOperations0;

protected function countOperations1 "function countOperations1
  author: Frenkel TUD 2011-05
  count the mathematical operations ((+,-),(*,/),(other))"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input tuple<Integer,Integer,Integer> inTpl;
  output tuple<Integer,Integer,Integer> outTpl;
algorithm
  outTpl:=
  matchcontinue (isyst,ishared,inTpl)
    local
      BackendDAE.Shared shared;
      array<DAE.ClassAttributes> clsAttrs;
      BackendDAE.EquationArray eqns;
     
    case (BackendDAE.EQSYSTEM(orderedEqs = eqns),shared,_)
      then
        BackendDAEUtil.traverseBackendDAEExpsEqns(eqns,countOperationsExp,inTpl);
  end matchcontinue;
end countOperations1;

protected function countOperationstraverseComps "function countOperationstraverseComps
  author: Frenkel TUD 2012-05"
  input BackendDAE.StrongComponents inComps;
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  input tuple<Integer,Integer,Integer> inTpl;
  output tuple<Integer,Integer,Integer> outTpl;
algorithm
  outTpl := 
  matchcontinue (inComps,isyst,ishared,inTpl)
    local
      Integer e;
      BackendDAE.StrongComponent comp,comp1;
      BackendDAE.StrongComponents rest;
      BackendDAE.EquationArray eqns;
      BackendDAE.Equation eqn;
      tuple<Integer,Integer,Integer> tpl;
      list<BackendDAE.Equation> eqnlst;
      Option<list<tuple<Integer, Integer, BackendDAE.Equation>>> jac;
      list<BackendDAE.Var> varlst;
      list<DAE.Exp> explst;
      DAE.FunctionTree funcs;
      list<tuple<Integer,list<Integer>>> eqnvartpllst;
      list<Integer> vlst;
    case ({},_,_,_) then inTpl; 
    case (BackendDAE.SINGLEEQUATION(eqn=e)::rest,_,_,_) 
      equation
        eqns = BackendEquation.daeEqns(isyst);
        eqn = BackendDAEUtil.equationNth(eqns, e-1);
        (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case ((comp as BackendDAE.MIXEDEQUATIONSYSTEM(condSystem=comp1))::rest,_,_,_) 
      equation
        tpl = countOperationstraverseComps({comp1},isyst,ishared,inTpl);
        (eqnlst,_,_) = BackendDAETransform.getEquationAndSolvedVar(comp, BackendEquation.daeEqns(isyst), BackendVariable.daeVars(isyst));
        tpl = BackendDAEUtil.traverseBackendDAEExpsEqns(BackendEquation.listEquation(eqnlst),countOperationsExp,tpl);
      then
        countOperationstraverseComps(rest,isyst,ishared,tpl);
    case ((comp as BackendDAE.EQUATIONSYSTEM(jac=jac,jacType=BackendDAE.JAC_TIME_VARYING()))::rest,_,BackendDAE.SHARED(functionTree=funcs),_) 
      equation
        (eqnlst,varlst,_) = BackendDAETransform.getEquationAndSolvedVar(comp, BackendEquation.daeEqns(isyst), BackendVariable.daeVars(isyst));
        tpl = addJacSpecificOperations(listLength(eqnlst),inTpl);
        tpl = countOperationsJac(jac,tpl);        
        ((_,explst,_,_)) = BackendEquation.traverseBackendDAEEqns(BackendEquation.listEquation(eqnlst),BackendEquation.equationToExp,(BackendVariable.listVar1(varlst),{},{},SOME(funcs)));
        ((_,tpl)) = Expression.traverseExpList(explst,countOperationsExp,tpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case ((comp as BackendDAE.EQUATIONSYSTEM(jac=_))::rest,_,_,_) 
      equation
        (eqnlst,_,_) = BackendDAETransform.getEquationAndSolvedVar(comp, BackendEquation.daeEqns(isyst), BackendVariable.daeVars(isyst));
        tpl = BackendDAEUtil.traverseBackendDAEExpsEqns(BackendEquation.listEquation(eqnlst),countOperationsExp,inTpl);
      then
        countOperationstraverseComps(rest,isyst,ishared,tpl);
    case (BackendDAE.SINGLEARRAY(eqn=e)::rest,_,_,_)
      equation 
         eqn = BackendDAEUtil.equationNth(BackendEquation.daeEqns(isyst), e-1);
         (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case (BackendDAE.SINGLEIFEQUATION(eqn=e)::rest,_,_,_)
      equation 
         eqn = BackendDAEUtil.equationNth(BackendEquation.daeEqns(isyst), e-1);
         (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl); 
    case (BackendDAE.SINGLEALGORITHM(eqn=e)::rest,_,_,_)
      equation
         eqn = BackendDAEUtil.equationNth(BackendEquation.daeEqns(isyst), e-1);
         (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case (BackendDAE.SINGLECOMPLEXEQUATION(eqn=e)::rest,_,_,_)
      equation 
         eqn = BackendDAEUtil.equationNth(BackendEquation.daeEqns(isyst), e-1);
         (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case (BackendDAE.SINGLEWHENEQUATION(eqn=e)::rest,_,_,_)
      equation 
         eqn = BackendDAEUtil.equationNth(BackendEquation.daeEqns(isyst), e-1);
         (_,tpl) = BackendEquation.traverseBackendDAEExpsEqn(eqn,countOperationsExp,inTpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);
    case ((comp as BackendDAE.TORNSYSTEM(tearingvars=vlst, otherEqnVarTpl=eqnvartpllst, linear=_))::rest,_,BackendDAE.SHARED(functionTree=funcs),_) 
      equation
        (eqnlst,varlst,_) = BackendDAETransform.getEquationAndSolvedVar(comp, BackendEquation.daeEqns(isyst), BackendVariable.daeVars(isyst));
        tpl = addJacSpecificOperations(listLength(vlst),inTpl);
        ((_,explst,_,_)) = BackendEquation.traverseBackendDAEEqns(BackendEquation.listEquation(eqnlst),BackendEquation.equationToExp,(BackendVariable.listVar1(varlst),{},{},SOME(funcs)));
        ((_,tpl)) = Expression.traverseExpList(explst,countOperationsExp,tpl);
      then 
         countOperationstraverseComps(rest,isyst,ishared,tpl);  
    case (_::rest,_,_,_) 
      equation
        true = Flags.isSet(Flags.FAILTRACE);
        Debug.traceln("BackendDAEOptimize.countOperationstraverseComps failed!");
      then
         countOperationstraverseComps(rest,isyst,ishared,inTpl);
    case (_::rest,_,_,_) 
      then
        countOperationstraverseComps(rest,isyst,ishared,inTpl);
  end matchcontinue;
end countOperationstraverseComps;

protected function countOperationsJac
  input Option<list<tuple<Integer, Integer, BackendDAE.Equation>>> inJac;
  input tuple<Integer,Integer,Integer> inTpl;
  output tuple<Integer,Integer,Integer> outTpl;
algorithm
  outTpl := match(inJac,inTpl)
    local
      list<tuple<Integer, Integer, BackendDAE.Equation>> jac;
      case (NONE(),_) then inTpl;
      case (SOME(jac),_)
        then List.fold(jac,countOperationsJac1,inTpl);
  end match;
end countOperationsJac;

protected function countOperationsJac1
  input tuple<Integer, Integer, BackendDAE.Equation> inJac;
  input tuple<Integer,Integer,Integer> inTpl;
  output tuple<Integer,Integer,Integer> outTpl;
algorithm
  (_,outTpl) := BackendEquation.traverseBackendDAEExpsEqn(Util.tuple33(inJac),countOperationsExp,inTpl);
end countOperationsJac1;

protected function addJacSpecificOperations
  input Integer n;
  input tuple<Integer,Integer,Integer> inTpl;
  output tuple<Integer,Integer,Integer> outTpl;
protected
  Integer i1,i2,i3,i1_1,i2_1,n2,n3;
algorithm
  (i1,i2,i3) := inTpl;
  n2 := n*n;
  n3 := n*n*n;
  i1_1 := intDiv(2*n3+3*n2-5*n,6) + i1;
  i2_1 := intDiv(2*n3+6*n2-2*n,6) + i2;
  outTpl := (i1_1,i2_1,i3);
end addJacSpecificOperations;

protected function countOperationsExp
  input tuple<DAE.Exp, tuple<Integer,Integer,Integer>> inTpl;
  output tuple<DAE.Exp, tuple<Integer,Integer,Integer>> outTpl;
algorithm
  outTpl := matchcontinue inTpl
    local
      DAE.Exp exp;
      Integer i1,i2,i3,i1_1,i2_1,i3_1;
    case ((exp,(i1,i2,i3))) equation
      ((_,(i1_1,i2_1,i3_1))) = Expression.traverseExp(exp,traversecountOperationsExp,(i1,i2,i3));
    then ((exp,(i1_1,i2_1,i3_1)));
    case _ then inTpl;
  end matchcontinue;
end countOperationsExp;

protected function traversecountOperationsExp
  input tuple<DAE.Exp, tuple<Integer,Integer,Integer>> inTuple;
  output tuple<DAE.Exp, tuple<Integer,Integer,Integer>> outTuple;
algorithm
  outTuple := matchcontinue(inTuple)
    local
      DAE.Exp e;
      Integer i1,i2,i3,i1_1,i2_1,i3_1,iexp2;
      Real rexp2;
      DAE.Operator op;
    case ((e as DAE.BINARY(operator=DAE.POW(ty=_),exp2=DAE.RCONST(rexp2)),(i1,i2,i3))) equation
      iexp2 = realInt(rexp2);
      true = realEq(rexp2, intReal(iexp2));
      i2_1 = i2+intAbs(iexp2)-1;
      then ((e, (i1,i2_1,i3)));
    case ((e as DAE.BINARY(operator=op),(i1,i2,i3))) equation
      (i1_1,i2_1,i3_1) = countOperator(op,i1,i2,i3);
      then ((e, (i1_1,i2_1,i3_1)));
    case _ then inTuple;
  end matchcontinue;
end traversecountOperationsExp;

protected function countOperator
  input DAE.Operator op;
  input Integer inInt1;
  input Integer inInt2;
  input Integer inInt3;
  output Integer outInt1;
  output Integer outInt2;
  output Integer outInt3;
algorithm
  (outInt1,outInt2,outInt3) := match(op, inInt1, inInt2, inInt3)
    local
      DAE.Type tp;
      Integer i;
    case (DAE.ADD(ty=_),_,_,_)
      then (inInt1+1,inInt2,inInt3);
    case (DAE.SUB(ty=_),_,_,_)
      then (inInt1+1,inInt2,inInt3);
    case (DAE.MUL(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.DIV(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.POW(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.UMINUS(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.UMINUS_ARR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1,inInt2,inInt3+i);
    case (DAE.ADD_ARR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1+i,inInt2,inInt3);
    case (DAE.SUB_ARR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1+i,inInt2,inInt3);
    case (DAE.MUL_ARR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1,inInt2+i,inInt3);
    case (DAE.DIV_ARR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1,inInt2+i,inInt3);
    case (DAE.MUL_ARRAY_SCALAR(ty=tp),_,_,_) equation
      i = Expression.sizeOf(tp);
      then (inInt1,inInt2+i,inInt3);
    case (DAE.ADD_ARRAY_SCALAR(ty=_),_,_,_)
      then (inInt1+1,inInt2,inInt3);
    case (DAE.SUB_SCALAR_ARRAY(ty=_),_,_,_)
      then (inInt1+1,inInt2,inInt3);
    case (DAE.MUL_SCALAR_PRODUCT(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.MUL_MATRIX_PRODUCT(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.DIV_ARRAY_SCALAR(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.DIV_SCALAR_ARRAY(ty=_),_,_,_)
      then (inInt1,inInt2+1,inInt3);
    case (DAE.POW_ARRAY_SCALAR(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.POW_SCALAR_ARRAY(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.POW_ARR(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.POW_ARR2(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.AND(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.OR(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.NOT(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.NOT(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.LESS(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.LESSEQ(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.GREATER(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.GREATEREQ(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.EQUAL(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.NEQUAL(ty=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    case (DAE.USERDEFINED(fqName=_),_,_,_)
      then (inInt1,inInt2,inInt3+1);
    else
      then(inInt1,inInt2,inInt3+1);
  end match;
end countOperator;


/* 
 * simplify if equations
 *
 */

public function simplifyIfEquations
"function: simplifyIfEquations
  author: Frenkel TUD 2012-07
  This function traveres all if equations and if expressions and tries to simplify it by using the 
  information from evaluation of parameters"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := BackendDAEUtil.mapEqSystem(dae,simplifyIfEquationsWork);
end simplifyIfEquations;

protected function simplifyIfEquationsWork
"function: simplifyIfEquationsWork
  author: Frenkel TUD 2012-07
  This function traveres all if equations and tries to simplify it by using the 
  information from evaluation of parameters"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
algorithm
  (osyst,oshared) := matchcontinue (isyst,ishared)
    local
      BackendDAE.Variables vars,knvars;
      BackendDAE.EquationArray eqns;
      list<BackendDAE.Equation> eqnslst,asserts;
      BackendDAE.EqSystem syst;
      BackendDAE.Shared shared;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),shared as BackendDAE.SHARED(knownVars=knvars))
      equation
        // traverse the equations
        eqnslst = BackendEquation.equationList(eqns);
        // traverse equations in reverse order, than branch equations of if equaitions need no reverse
        ((eqnslst,asserts,true)) = List.fold1(listReverse(eqnslst), simplifyIfEquationsFinder, knvars, ({},{},false));
        eqns = BackendEquation.listEquation(eqnslst);
        syst = BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);
        shared = BackendEquation.requationsAddDAE(asserts,shared);
      then (syst,shared);
    case (_,_)
      then (isyst,ishared);
  end matchcontinue;
end simplifyIfEquationsWork;

protected function simplifyIfEquationsFinder
"function: simplifyIfEquationsFinder
  author: Frenkel TUD 2012-07
  helper for simplifyIfEquations"
  input BackendDAE.Equation inElem;
  input BackendDAE.Variables inConstArg;
  input tuple<list<BackendDAE.Equation>,list<BackendDAE.Equation>,Boolean> inArg;
  output tuple<list<BackendDAE.Equation>,list<BackendDAE.Equation>,Boolean> outArg;
algorithm
  outArg := matchcontinue(inElem,inConstArg,inArg)
    local
      list<DAE.Exp> explst;
      list<BackendDAE.Equation> eqnslst,acc,asserts,asserts1;
      list<list<BackendDAE.Equation>> eqnslstlst;
      DAE.ElementSource source;
      BackendDAE.Variables knvars;
      Boolean b;
      BackendDAE.Equation eqn;
    case (BackendDAE.IF_EQUATION(conditions=explst, eqnstrue=eqnslstlst, eqnsfalse=eqnslst, source=source),knvars,(acc,asserts,_))
      equation
        // check conditions
        ((explst,_)) = Expression.traverseExpList(explst, simplifyevaluatedParamter, (knvars,false));
        explst = ExpressionSimplify.simplifyList(explst, {});
        // simplify if equation
        (acc,asserts1) = simplifyIfEquation(explst,eqnslstlst,eqnslst,{},{},source,knvars,acc);
        asserts = listAppend(asserts,asserts1);
      then
        ((acc,asserts,true));
    case (eqn,knvars,(acc,asserts,b))
      equation
        (eqn,(_,b)) = BackendEquation.traverseBackendDAEExpsEqn(eqn, simplifyIfExpevaluatedParamter, (knvars,b));
      then 
        ((eqn::acc,asserts,b));
  end matchcontinue;
end simplifyIfEquationsFinder;

protected function simplifyIfExpevaluatedParamter
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean>> tpl1;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean>> tpl2;
algorithm
  tpl2 := matchcontinue(tpl1)
    local
      BackendDAE.Variables knvars;
      DAE.Exp e,cond,expThen,expElse;
      Boolean b,b1;
    case ((e as DAE.IFEXP(expCond=cond, expThen=expThen, expElse=expElse),(knvars,b)))
      equation
        ((cond,(_,b1))) = Expression.traverseExp(cond, simplifyevaluatedParamter, (knvars,false));
        e = Util.if_(b1,DAE.IFEXP(cond,expThen,expElse),e);
        (e,_) = ExpressionSimplify.condsimplify(b1,e);
      then
        ((e,(knvars,b or b1)));
    case _ then tpl1;   
  end matchcontinue;
end simplifyIfExpevaluatedParamter;

protected function simplifyevaluatedParamter
  input tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean>> tpl1;
  output tuple<DAE.Exp, tuple<BackendDAE.Variables,Boolean>> tpl2;
algorithm
  tpl2 := matchcontinue(tpl1)
    local
      BackendDAE.Variables knvars;
      DAE.ComponentRef cr;
      BackendDAE.Var v;
      DAE.Exp e;
      Boolean b;
    case ((DAE.CREF(componentRef = cr),(knvars,_)))
      equation
        (v::{},_::{}) = BackendVariable.getVar(cr,knvars);
        true = BackendVariable.isFinalVar(v);
        e = BackendVariable.varBindExpStartValue(v);    
      then
        ((e,(knvars,true)));
    case _ then tpl1;   
  end matchcontinue;
end simplifyevaluatedParamter;

protected function simplifyIfEquation
"function: simplifyIfEquation
  author: Frenkel TUD 2012-07
  helper for simplifyIfEquations"
  input list<DAE.Exp> conditions;
  input list<list<BackendDAE.Equation>> theneqns;
  input list<BackendDAE.Equation> elseenqs;
  input list<DAE.Exp> conditions1;
  input list<list<BackendDAE.Equation>> theneqns1;
  input DAE.ElementSource source;
  input BackendDAE.Variables knvars;  
  input list<BackendDAE.Equation> inEqns;
  output list<BackendDAE.Equation> outEqns;
  output list<BackendDAE.Equation> outAsserts;
algorithm
  (outEqns,outAsserts) := match(conditions,theneqns,elseenqs,conditions1,theneqns1,source,knvars,inEqns)
    local
      DAE.Exp e;
      list<DAE.Exp> explst;     
      list<list<BackendDAE.Equation>> eqnslst;
      list<BackendDAE.Equation> eqns,elseenqs1,asserts;
      
    // no true case left with condition<>false
    case ({},{},_,{},{},_,_,_) 
      equation
        // simplify nested if equations
        ((eqns,asserts,_)) = List.fold1(listReverse(elseenqs), simplifyIfEquationsFinder, knvars, ({},{},false));
      then 
        (listAppend(eqns,inEqns),asserts);
    // true case left with condition<>false
    case ({},{},_,_,_,_,_,_)
      equation
        explst = listReverse(conditions1);
        eqnslst = listReverse(theneqns1);
        // simplify nested if equations
        ((elseenqs1,asserts,_)) = List.fold1(listReverse(elseenqs), simplifyIfEquationsFinder, knvars, ({},{},false));
        elseenqs1 = listAppend(elseenqs1,asserts);
        (eqnslst,elseenqs1,asserts) = simplifyIfEquationAsserts(explst,eqnslst,elseenqs1,{},{},{});
        eqns = simplifyIfEquation1(explst,eqnslst,elseenqs1,source,knvars,inEqns);
      then 
        (eqns,asserts);
    // if true and first use it 
    case(DAE.BCONST(true)::_,eqns::_,_,{},_,_,_,_)
      equation
        // simplify nested if equations
        ((eqns,asserts,_)) = List.fold1(listReverse(eqns), simplifyIfEquationsFinder, knvars, ({},{},false));
      then 
        (listAppend(eqns,inEqns),asserts);
    // if true and not first use it as new else
    case(DAE.BCONST(true)::_,eqns::_,_,_,_,_,_,_)
      equation
        explst = listReverse(conditions1);
        eqnslst = listReverse(theneqns1);
        // simplify nested if equations
        ((elseenqs1,asserts,_)) = List.fold1(listReverse(eqns), simplifyIfEquationsFinder, knvars, ({},{},false));
        elseenqs1 = listAppend(elseenqs1,asserts);
        (eqnslst,elseenqs1,asserts) = simplifyIfEquationAsserts(explst,eqnslst,elseenqs1,{},{},{});
        eqns = simplifyIfEquation1(explst,eqnslst,elseenqs1,source,knvars,inEqns);
      then 
        (eqns,asserts);
    // if false skip it
    case(DAE.BCONST(false)::explst,_::eqnslst,_,_,_,_,_,_)
      equation
        (eqns,asserts) = simplifyIfEquation(explst,eqnslst,elseenqs,conditions1,theneqns1,source,knvars,inEqns);
      then
        (eqns,asserts);
    // all other cases
    case(e::explst,eqns::eqnslst,_,_,_,_,_,_)
      equation
        // simplify nested if equations
        ((eqns,asserts,_)) = List.fold1(listReverse(eqns), simplifyIfEquationsFinder, knvars, ({},{},false));
        eqns = listAppend(eqns,asserts);
        (eqns,asserts) = simplifyIfEquation(explst,eqnslst,elseenqs,e::conditions1,eqns::theneqns1,source,knvars,inEqns);
      then
        (eqns,asserts);
  end match;
end simplifyIfEquation;

protected function simplifyIfEquation1
"function: simplifyIfEquation1
  author: Frenkel TUD 2012-07
  helper for simplifyIfEquations"
  input list<DAE.Exp> conditions;
  input list<list<BackendDAE.Equation>> theneqns;
  input list<BackendDAE.Equation> elseenqs;
  input DAE.ElementSource source;
  input BackendDAE.Variables knvars;  
  input list<BackendDAE.Equation> inEqns;
  output list<BackendDAE.Equation> outEqns;
algorithm
  outEqns := matchcontinue(conditions,theneqns,elseenqs,source,knvars,inEqns)
    local
      DAE.Exp e;
      list<DAE.Exp> explst,fbsExp;
      list<list<DAE.Exp>> tbsExp;      
      list<list<BackendDAE.Equation>> eqnslst;
      list<BackendDAE.Equation> eqns;
      HashTable2.HashTable ht;
      list<tuple<DAE.ComponentRef,DAE.Exp>> crexplst;
      
    // true case left with condition<>false
    case (_,_,_,_,_,_)
      equation
        _ = countEquationsInBranches(theneqns,elseenqs,source);
        // simplify if eqution 
        // if .. then a=.. elseif .. then a=... else a=.. end if;
        // to 
        // a=if .. then .. else if .. then else ..;
        ht = HashTable2.emptyHashTable();
        ht = simplifySolvedIfEqnsElse(elseenqs,ht);
        ht = simplifySolvedIfEqns(listReverse(conditions),listReverse(theneqns),ht);
        crexplst = BaseHashTable.hashTableList(ht);
        eqns = simplifySolvedIfEqns2(crexplst,inEqns);
        // ToDo: check if the same cref is not used more than once on the lhs, merge sources        
      then 
        eqns;
    case (_,_,_,_,_,_)
      equation
        _ = countEquationsInBranches(theneqns,elseenqs,source);
        fbsExp = makeEquationLstToResidualExpLst(elseenqs);
        tbsExp = List.map(theneqns, makeEquationLstToResidualExpLst);
        eqns = makeEquationsFromResiduals(conditions, tbsExp, fbsExp, source);
      then 
        listAppend(eqns,inEqns);
    case (_,_,_,_,_,_)
      then
        BackendDAE.IF_EQUATION(conditions,theneqns,elseenqs,source)::inEqns;
  end matchcontinue;
end simplifyIfEquation1;

protected function simplifySolvedIfEqns2
  input list<tuple<DAE.ComponentRef,DAE.Exp>> crexplst;
  input list<BackendDAE.Equation> inEqns;
  output list<BackendDAE.Equation> outEqns;
algorithm
  outEqns := match(crexplst,inEqns)
    local
      DAE.ComponentRef cr;
      DAE.Exp e,crexp;
      list<tuple<DAE.ComponentRef,DAE.Exp>> rest;
    case ({},_)
      then
        inEqns;
    case ((cr,e)::rest,_)
      equation
        crexp = Expression.crefExp(cr);
      then
       simplifySolvedIfEqns2(rest,BackendDAE.EQUATION(crexp,e,DAE.emptyElementSource,false)::inEqns);       
  end match;
end simplifySolvedIfEqns2;

protected function simplifySolvedIfEqns
"function: simplifySolvedIfEqns
  author: Frenkel TUD 2012-10
  helper for simplifyIfEquations"
  input list<DAE.Exp> conditions;
  input list<list<BackendDAE.Equation>> theneqns;
  input HashTable2.HashTable iHt;
  output HashTable2.HashTable oHt;
algorithm
  oHt := match(conditions,theneqns,iHt)
    local
      HashTable2.HashTable ht;
      DAE.Exp c;
      list<DAE.Exp> explst;
      list<BackendDAE.Equation> eqns;
      list<list<BackendDAE.Equation>> rest;
    case ({},{},_)
      then
        iHt;
    case (c::explst,eqns::rest,_)
      equation
        ht = simplifySolvedIfEqns1(c,eqns,iHt);
      then
        simplifySolvedIfEqns(explst,rest,ht);
  end match;
end simplifySolvedIfEqns;

protected function simplifySolvedIfEqns1
"function: simplifySolvedIfEqns1
  author: Frenkel TUD 2012-10
  helper for simplifyIfEquations"
  input DAE.Exp condition;
  input list<BackendDAE.Equation> brancheqns;
  input HashTable2.HashTable iHt;
  output HashTable2.HashTable oHt;
algorithm
  oHt := match(condition,brancheqns,iHt)
    local
      DAE.ComponentRef cr;
      DAE.Exp e,exp;
      DAE.ElementSource source;
      HashTable2.HashTable ht;
      list<BackendDAE.Equation> rest;
    case (_,{},_)
      then
        iHt;
    case (_,BackendDAE.EQUATION(exp=DAE.CREF(componentRef=cr), scalar=e, source=source)::rest,_)
      equation
        false = Expression.expHasCref(e, cr);
        exp = BaseHashTable.get(cr, iHt);
        exp = DAE.IFEXP(condition, e, exp);
        ht = BaseHashTable.add((cr,exp), iHt);
      then
        simplifySolvedIfEqns1(condition,rest,ht);
    case (_,BackendDAE.EQUATION(exp=DAE.UNARY(operator=DAE.UMINUS(ty=_), exp=DAE.CREF(componentRef=cr)), scalar=e, source=source)::rest,_)
      equation
        false = Expression.expHasCref(e, cr);
        exp = BaseHashTable.get(cr, iHt);
        e = Expression.negate(e);
        exp = DAE.IFEXP(condition, e, exp);
        ht = BaseHashTable.add((cr,exp), iHt);
      then
        simplifySolvedIfEqns1(condition,rest,ht);
  end match;
end simplifySolvedIfEqns1;

protected function simplifySolvedIfEqnsElse
"function: simplifySolvedIfEqnsElse
  author: Frenkel TUD 2012-10
  helper for simplifyIfEquations"
  input list<BackendDAE.Equation> elseenqs;
  input HashTable2.HashTable iHt;
  output HashTable2.HashTable oHt;
algorithm
  oHt := match(elseenqs,iHt)
    local
      DAE.ComponentRef cr;
      DAE.Exp e;
      DAE.ElementSource source;
      HashTable2.HashTable ht;
      list<BackendDAE.Equation> rest;
    case ({},_)
      then
        iHt;
    case (BackendDAE.EQUATION(exp=DAE.CREF(componentRef=cr), scalar=e, source=source)::rest,_)
      equation
        failure( _ = BaseHashTable.get(cr, iHt));
        false = Expression.expHasCref(e, cr);
        ht = BaseHashTable.add((cr,e), iHt);
      then
        simplifySolvedIfEqnsElse(rest,ht);
    case (BackendDAE.EQUATION(exp=DAE.UNARY(operator=DAE.UMINUS(ty=_), exp=DAE.CREF(componentRef=cr)), scalar=e, source=source)::rest,_)
      equation
        failure( _ = BaseHashTable.get(cr, iHt));
        false = Expression.expHasCref(e, cr);
        e = Expression.negate(e);
        ht = BaseHashTable.add((cr,e), iHt);
      then
        simplifySolvedIfEqnsElse(rest,ht);
  end match;
end simplifySolvedIfEqnsElse;

protected function simplifyIfEquationAsserts
"function: simplifyIfEquationAsserts
  author: Frenkel TUD 2012-07
  helper for simplifyIfEquations"
  input list<DAE.Exp> conditions;
  input list<list<BackendDAE.Equation>> theneqns;
  input list<BackendDAE.Equation> elseenqs;
  input list<DAE.Exp> conditions1; 
  input list<list<BackendDAE.Equation>> theneqns1;
  input list<BackendDAE.Equation> inEqns;
  output list<list<BackendDAE.Equation>> otheneqns;
  output list<BackendDAE.Equation> oelseenqs;
  output list<BackendDAE.Equation> outEqns;
algorithm
  (otheneqns,oelseenqs,outEqns) := match(conditions,theneqns,elseenqs,conditions1,theneqns1,inEqns)
    local
      DAE.Exp e;
      list<DAE.Exp> explst;
      list<BackendDAE.Equation> eqns,eqns1,beqns;
      list<list<BackendDAE.Equation>> eqnslst,eqnslst1;

    case (_,{},_,_,_,_)
      equation
        (beqns,eqns) = simplifyIfEquationAsserts1(elseenqs,NONE(),conditions1,{},inEqns);  
      then
        (listReverse(theneqns1),beqns,eqns);
    case (e::explst,eqns::eqnslst,_,_,_,_)
      equation
        (beqns,eqns) = simplifyIfEquationAsserts1(eqns,SOME(e),conditions1,{},inEqns);
        (eqnslst1,eqns1,eqns) = simplifyIfEquationAsserts(explst,eqnslst,elseenqs,e::conditions1,beqns::theneqns1,eqns);
      then
        (eqnslst1,eqns1,eqns);
  end match;
end simplifyIfEquationAsserts;

protected function simplifyIfEquationAsserts1
"function: simplifyIfEquationAsserts1
  author: Frenkel TUD 2012-07
  helper for simplifyIfEquationAsserts"
  input list<BackendDAE.Equation> brancheqns;
  input Option<DAE.Exp> condition;
  input list<DAE.Exp> conditions "reversed";
  input list<BackendDAE.Equation> brancheqns1;
  input list<BackendDAE.Equation> inEqns;
  output list<BackendDAE.Equation> obrancheqns;
  output list<BackendDAE.Equation> outEqns;
algorithm
  (obrancheqns,outEqns) := match(brancheqns,condition,conditions,brancheqns1,inEqns)
    local
      DAE.Exp e,cond,msg,level;
      list<DAE.Exp> explst;
      BackendDAE.Equation eqn;
      list<BackendDAE.Equation> eqns,beqns;
      list<list<BackendDAE.Equation>> eqnslst;
      Integer size;
      DAE.ElementSource source,source1;
    case ({},_,_,_,_)
      then
        (listReverse(brancheqns1),inEqns);  
    case (BackendDAE.ALGORITHM(size=size,alg=DAE.ALGORITHM_STMTS({DAE.STMT_ASSERT(cond=cond,msg=msg,level=level,source=source1)}),source=source)::eqns,NONE(),_,_,_)
      equation
        e = List.fold(conditions,makeIfExp,cond);
        (beqns,eqns) =  simplifyIfEquationAsserts1(eqns,condition,conditions,brancheqns1,BackendDAE.ALGORITHM(size,DAE.ALGORITHM_STMTS({DAE.STMT_ASSERT(e,msg,level,source1)}),source)::inEqns);
      then
        (beqns,eqns);
    case (BackendDAE.ALGORITHM(size=size,alg=DAE.ALGORITHM_STMTS({DAE.STMT_ASSERT(cond=cond,msg=msg,level=level,source=source1)}),source=source)::eqns,SOME(e),_,_,_)
      equation
        e = DAE.IFEXP(e,cond,DAE.BCONST(true));
        e = List.fold(conditions,makeIfExp,e);
        (beqns,eqns) = simplifyIfEquationAsserts1(eqns,condition,conditions,brancheqns1,BackendDAE.ALGORITHM(size,DAE.ALGORITHM_STMTS({DAE.STMT_ASSERT(e,msg,level,source1)}),source)::inEqns);
      then 
        (beqns,eqns);
    case (BackendDAE.ALGORITHM(size=size,alg=DAE.ALGORITHM_STMTS({DAE.STMT_TERMINATE(msg=msg,source=source1)}),source=source)::eqns,NONE(),_,_,_)
      equation
        e = List.fold(conditions,makeIfExp,DAE.BCONST(true));
        (beqns,eqns) =  simplifyIfEquationAsserts1(eqns,condition,conditions,brancheqns1,BackendDAE.ALGORITHM(size,DAE.ALGORITHM_STMTS({DAE.STMT_IF(e,{DAE.STMT_TERMINATE(msg,source1)},DAE.NOELSE(),source1)}),source)::inEqns);
      then
        (beqns,eqns);
    case (BackendDAE.ALGORITHM(size=size,alg=DAE.ALGORITHM_STMTS({DAE.STMT_TERMINATE(msg=msg,source=source1)}),source=source)::eqns,SOME(e),_,_,_)
      equation
        e = List.fold(conditions,makeIfExp,e);
        (beqns,eqns) = simplifyIfEquationAsserts1(eqns,condition,conditions,brancheqns1,BackendDAE.ALGORITHM(size,DAE.ALGORITHM_STMTS({DAE.STMT_IF(e,{DAE.STMT_TERMINATE(msg,source1)},DAE.NOELSE(),source1)}),source)::inEqns);
      then 
        (beqns,eqns);        
    case (eqn::eqns,_,_,_,_)
      equation
        (beqns,eqns) = simplifyIfEquationAsserts1(eqns,condition,conditions,eqn::brancheqns1,inEqns);
      then
        (beqns,eqns);
  end match;
end simplifyIfEquationAsserts1;

protected function makeIfExp
  input DAE.Exp cond;
  input DAE.Exp else_;
  output DAE.Exp oExp;
algorithm
  oExp := DAE.IFEXP(cond,DAE.BCONST(true),else_);
end makeIfExp;

protected function countEquationsInBranches "
Checks that the number of equations is the same in all branches
of an if-equation"
  input list<list<BackendDAE.Equation>> trueBranches;
  input list<BackendDAE.Equation> falseBranch;
  input DAE.ElementSource source;
  output Integer nrOfEquations;
algorithm
  nrOfEquations := matchcontinue(trueBranches,falseBranch,source)
    local
      list<Boolean> b;
      list<String> strs;
      String str,eqstr;
      list<Integer> nrOfEquationsBranches;
    case (_,_,_)
      equation
        nrOfEquations = BackendEquation.equationLstSize(falseBranch);
        nrOfEquationsBranches = List.map(trueBranches, BackendEquation.equationLstSize);
        b = List.map1(nrOfEquationsBranches, intEq, nrOfEquations);
        true = List.reduce(b,boolAnd);
      then (nrOfEquations);
    case (_,_,_)
      equation
        nrOfEquations = BackendEquation.equationLstSize(falseBranch);
        nrOfEquationsBranches = List.map(trueBranches, BackendEquation.equationLstSize);
        eqstr = stringDelimitList(List.map(listAppend(trueBranches,{falseBranch}),BackendDump.dumpEqnsStr),"\n");
        strs = List.map(nrOfEquationsBranches, intString);
        str = stringDelimitList(strs,",");
        str = "{" +& str +& "," +& intString(nrOfEquations) +& "}";
        Error.addSourceMessage(Error.IF_EQUATION_UNBALANCED_2,{str,eqstr},DAEUtil.getElementSourceFileInfo(source));
      then fail();
  end matchcontinue;
end countEquationsInBranches;

protected function makeEquationLstToResidualExpLst 
  input list<BackendDAE.Equation> eqLst;
  output list<DAE.Exp> oExpLst;
algorithm
  oExpLst := matchcontinue(eqLst)
    local
      list<BackendDAE.Equation> rest;
      list<DAE.Exp> exps1,exps2,exps;
      BackendDAE.Equation eq;
      DAE.ElementSource source;
      String str;
    case ({}) then {};
    case ((eq as BackendDAE.ALGORITHM(source = source))::rest)
      equation
        str = BackendDump.equationString(eq);
        str = Util.stringReplaceChar(str,"\n","");
        Error.addSourceMessage(Error.IF_EQUATION_WARNING,{str},DAEUtil.getElementSourceFileInfo(source));
        exps = makeEquationLstToResidualExpLst(rest);
      then exps;
    case (eq::rest)
      equation
        exps1 = makeEquationToResidualExpLst(eq);
        exps2 = makeEquationLstToResidualExpLst(rest);
        exps = listAppend(exps1,exps2);
      then 
        exps;
  end matchcontinue;
end makeEquationLstToResidualExpLst;

protected function makeEquationToResidualExpLst "
If-equations with more than 1 equation in each branch cannot be transformed
to a single equation with residual if-expression. This function translates such
equations to a list of residual if-expressions. Normal equations are translated 
to a list with a single residual expression."
  input BackendDAE.Equation eq;
  output list<DAE.Exp> oExpLst;
algorithm
  oExpLst := matchcontinue(eq)
    local
      list<list<BackendDAE.Equation>> tbs;
      list<BackendDAE.Equation> fbs;
      list<DAE.Exp> conds, fbsExp,exps;
      list<list<DAE.Exp>> tbsExp;
      BackendDAE.Equation elt;
      DAE.Exp exp;

    case (BackendDAE.IF_EQUATION(conditions=conds,eqnstrue=tbs,eqnsfalse=fbs))
      equation
        fbsExp = makeEquationLstToResidualExpLst(fbs);
        tbsExp = List.map(tbs, makeEquationLstToResidualExpLst);
        exps = makeResidualIfExpLst(conds,tbsExp,fbsExp);
      then
        exps;
    case (elt)
      equation
        exp=makeEquationToResidualExp(elt);
      then
        {exp};
  end matchcontinue;
end makeEquationToResidualExpLst;

protected function makeResidualIfExpLst
  input list<DAE.Exp> inExp1;
  input list<list<DAE.Exp>> inExpLst2;
  input list<DAE.Exp> inExpLst3;
  output list<DAE.Exp> outExpLst;
algorithm
  outExpLst := match (inExp1,inExpLst2,inExpLst3)
    local
      list<list<DAE.Exp>> tbs,tbsRest;
      list<DAE.Exp> tbsFirst,fbs,rest_res;
      list<DAE.Exp> conds;
      DAE.Exp ifexp,fb;

    case (_,tbs,{})
      equation
        List.map_0(tbs, List.assertIsEmpty);
      then {};

    case (conds,tbs,fb::fbs)
      equation
        tbsRest = List.map(tbs,List.rest);
        rest_res = makeResidualIfExpLst(conds, tbsRest, fbs);

        tbsFirst = List.map(tbs,List.first);

        ifexp = Expression.makeNestedIf(conds,tbsFirst,fb);
      then
        (ifexp :: rest_res);
  end match;
end makeResidualIfExpLst;

protected function makeEquationToResidualExp ""
  input BackendDAE.Equation eq;
  output DAE.Exp oExp;
algorithm
  oExp := matchcontinue(eq)
    local
      DAE.Exp e1,e2;
      DAE.ComponentRef cr1;
      String str;
      DAE.Type ty;
    // normal equation
    case(BackendDAE.EQUATION(exp=e1,scalar=e2))
      equation
        ty = Expression.typeof(e1);
        true = Types.isIntegerOrRealOrSubTypeOfEither(ty);
        oExp = Expression.expSub(e1,e2);
      then
        oExp;
    // equation from array TODO! check if this works!
    case(BackendDAE.ARRAY_EQUATION(left=e1,right=e2))
      equation
        oExp = Expression.expSub(e1,e2);
      then
        oExp;       
    // solved equation
    case(BackendDAE.SOLVED_EQUATION(componentRef=cr1, exp=e2))
      equation
        e1 = Expression.crefExp(cr1);
        oExp = Expression.expSub(e1,e2);
      then
        oExp;
    // residual equation
    case(BackendDAE.RESIDUAL_EQUATION(exp = oExp))
      then
        oExp;
    // complex equation
    case(BackendDAE.COMPLEX_EQUATION(left = e1, right = e2))
      equation
        oExp = Expression.expSub(e1,e2);
      then
        oExp;
    // failure
    case _
      equation
        str = "- BackendDAEOptimize.makeEquationToResidualExp failed to transform equation: " +& BackendDump.equationString(eq) +& " to residual form!";
        Error.addMessage(Error.INTERNAL_ERROR, {str});
      then fail();
  end matchcontinue;
end makeEquationToResidualExp;

protected function makeEquationsFromResiduals
  input list<DAE.Exp> inExp1;
  input list<list<DAE.Exp>> inExpLst2;
  input list<DAE.Exp> inExpLst3;
  input DAE.ElementSource source "the origin of the element";
  output list<BackendDAE.Equation> outExpLst;
algorithm
  outExpLst := match (inExp1,inExpLst2,inExpLst3,source)
    local
      list<list<DAE.Exp>> tbs,tbsRest;
      list<DAE.Exp> tbsFirst,fbs;
      list<DAE.Exp> conds;
      DAE.Exp ifexp,fb;
      BackendDAE.Equation eq;
      list<BackendDAE.Equation> rest_res;
      DAE.ElementSource src;

    case (_,tbs,{},_)
      equation
        List.map_0(tbs, List.assertIsEmpty);
      then {};

    case (conds,tbs,fb::fbs,src)
      equation
        tbsRest = List.map(tbs,List.rest);
        rest_res = makeEquationsFromResiduals(conds, tbsRest,fbs,src);

        tbsFirst = List.map(tbs,List.first);

        ifexp = Expression.makeNestedIf(conds,tbsFirst,fb);
        eq = BackendDAE.EQUATION(DAE.RCONST(0.0),ifexp,src,false);
      then
        (eq :: rest_res);
  end match;
end makeEquationsFromResiduals;


/* 
 * simplify semiLinear calls 
 *
 */

public function simplifysemiLinear
"function: simplifysemiLinear
  author: Frenkel TUD 2012-08
  This function traveres all equations and tries to simplify calls to semiLinear"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := BackendDAEUtil.mapEqSystem(dae,simplifysemiLinearWork);
end simplifysemiLinear;

protected function simplifysemiLinearWork
"function: simplifysemiLinearWork
  author: Frenkel TUD 2012-08
  This function traveres all equations and tries to simplify calls to semiLinear"
  input BackendDAE.EqSystem isyst;
  input BackendDAE.Shared ishared;
  output BackendDAE.EqSystem osyst;
  output BackendDAE.Shared oshared;
algorithm
  (osyst,oshared) := matchcontinue (isyst,ishared)
    local
      BackendDAE.Variables vars,knvars;
      BackendDAE.EquationArray eqns;
      list<tuple<BackendDAE.Equation,Integer>> eqnslst;
      BackendDAE.EqSystem syst;
      BackendDAE.Shared shared;
      Boolean b;
      HashTableExpToIndex.HashTable ht;
      array<list<tuple<BackendDAE.Equation,Integer>>> eqnsarray;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),shared)
      equation
        // traverse the equations and collect all semiLinear calls  y=semiLinear(x,sa,sb)
        (eqns,(eqnslst,_,true)) = BackendEquation.traverseBackendDAEEqnsWithUpdate(eqns,simplifysemiLinearFinder,({},0,false));
        // sort for (y,x) pairs
        eqnsarray = arrayCreate(5,{});
        ht = HashTableExpToIndex.emptyHashTable();
        eqnsarray = semiLinearSort(eqnslst,ht,1,eqnsarray);
        eqnsarray = semiLinearSort1(arrayList(eqnsarray),1,arrayCreate(5,{}));
        // optimize 
        // y = semiLinear(x,sa,s1)
        // y = semiLinear(x,s1,s2)
        // y = semiLinear(x,s2,s3)
        // ...
        // y = semiLinear(x,sn,sb)
        // -> 
        // s1 = if (x>=0) then sa else sb
        // s2 = s1
        // s3 = s2
        // ..
        // sn = sn-1
        // y = semiLinear(x,sa,sb)
        eqnslst = List.fold(arrayList(eqnsarray),semiLinearOptimize,{});
        // replace the equations in the system
        eqns = List.fold(eqnslst,semiLinearReplaceEqns,eqns);        
        syst = BackendDAE.EQSYSTEM(vars,eqns,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets);
      then (syst,shared);
    case (_,_)
      then (isyst,ishared);
  end matchcontinue;
end simplifysemiLinearWork;

protected function semiLinearReplaceEqns
"function: semiLinearReplaceEqns
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input tuple<BackendDAE.Equation,Integer> iTpl;
  input BackendDAE.EquationArray iEqns;
  output BackendDAE.EquationArray oEqns;
protected
  BackendDAE.Equation eqn;
  Integer index;
algorithm
  (eqn,index) := iTpl;
  Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Replace with ",eqn,"\n"));
  oEqns := BackendEquation.equationSetnth(iEqns, index, eqn);
end semiLinearReplaceEqns;

protected function semiLinearOptimize
"function: semiLinearOptimize
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input list<tuple<BackendDAE.Equation,Integer>> eqnslst;
  input list<tuple<BackendDAE.Equation,Integer>> iAcc;
  output list<tuple<BackendDAE.Equation,Integer>> oAcc;
algorithm
  oAcc := matchcontinue(eqnslst,iAcc)
    local
      HashTableExpToIndex.HashTable ht,ht1;
      array<tuple<BackendDAE.Equation,Integer>> eqnsarray;
      list<DAE.Exp> explst;
    case (_::{},_) then iAcc;
    case (_,_)
      equation
        // get HashMab sa-> index
        ht = HashTableExpToIndex.emptyHashTable();
        ht1 = HashTableExpToIndex.emptyHashTable();
        (ht,ht1) = semiLinearOptimize1(eqnslst,1,ht,ht1);
        // get sa
        explst = List.fold1(BaseHashTable.hashTableKeyList(ht),semiLinearGetSA,ht1,{}); 
        eqnsarray = listArray(eqnslst);
        // optimize
      then
        semiLinearOptimize2(explst,ht,eqnsarray,iAcc);
    case(_,_) then iAcc;
  end matchcontinue;
end semiLinearOptimize;

protected function semiLinearOptimize2
"function: semiLinearOptimize2
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input list<DAE.Exp> saLst;
  input HashTableExpToIndex.HashTable iHt;
  input array<tuple<BackendDAE.Equation,Integer>> IEqnsarray;
  input list<tuple<BackendDAE.Equation,Integer>> iAcc;
  output list<tuple<BackendDAE.Equation,Integer>> oAcc;
algorithm
  oAcc := matchcontinue(saLst,iHt,IEqnsarray,iAcc)
    local
      DAE.Exp sa,sb,s1,y,x;
      list<DAE.Exp> rest;
      list<tuple<DAE.Exp,Integer,DAE.ElementSource>> explst;
      array<tuple<BackendDAE.Equation,Integer>> eqnsarray;
      list<tuple<BackendDAE.Equation,Integer>> acc;
      HashTableExpToIndex.HashTable ht;
      BackendDAE.Equation eqn,eqn1;
      Integer i1,index,index1;
      Absyn.Path path;
      DAE.CallAttributes attr;
      DAE.ElementSource source,source1;
      Boolean diffed;
    case ({},_,_,_) then iAcc;
    case (sa::rest,_,_,_)
      equation
        i1 = BaseHashTable.get(sa,iHt);
        ((BackendDAE.EQUATION(exp=y,scalar=DAE.CALL(path=path,expLst = {x,_,s1},attr=attr),source=source,differentiated=diffed),index)) = IEqnsarray[i1];
        // get Order of s1,s2,s3,..,sn,sb
        (sb,source1,index1,explst) = semiLinearOptimize3(s1,source,index,iHt,IEqnsarray,{});
        // generate optimized equations
        // s1 = if (x>=0) then sa else sb
        // s2 = s1
        // ..
        // sn = sn-1
        // y = semiLinear(x,sa,sb)
        eqn = BackendDAE.EQUATION(s1,DAE.IFEXP(DAE.CALL(Absyn.IDENT("noEvent"),{DAE.RELATION(x,DAE.GREATEREQ(DAE.T_REAL_DEFAULT),DAE.RCONST(0.0),-1,NONE())},DAE.callAttrBuiltinBool),sa,sb),source,diffed);      
        eqn1 = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source1,diffed);      
        acc = semiLinearOptimize4(explst,(eqn1,index1)::iAcc);
      then
        semiLinearOptimize2(rest,iHt,IEqnsarray,(eqn,index)::acc);
    case (_::rest,_,_,_)
      then
        semiLinearOptimize2(rest,iHt,IEqnsarray,iAcc);        
  end matchcontinue;
end semiLinearOptimize2;

protected function semiLinearOptimize4
"function: semiLinearOptimize3
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input list<tuple<DAE.Exp,Integer,DAE.ElementSource>> explst;
  input list<tuple<BackendDAE.Equation,Integer>> iAcc;
  output list<tuple<BackendDAE.Equation,Integer>> oAcc;
algorithm
  oAcc := match(explst,iAcc)
    local
      DAE.Exp s1,s2;
      list<tuple<DAE.Exp,Integer,DAE.ElementSource>> rest;
      Integer index;
      BackendDAE.Equation eqn;
      DAE.ElementSource source;
    case ({},_) then iAcc;
    case (_::{},_) then iAcc;
    case((s2,index,source)::(rest as ((s1,_,_)::_)),_)
      equation
        eqn = BackendDAE.EQUATION(s2,s1,source,false);
      then
        semiLinearOptimize4(rest,(eqn,index)::iAcc);
  end match;
end semiLinearOptimize4;

protected function semiLinearOptimize3
"function: semiLinearOptimize3
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input DAE.Exp exp;
  input DAE.ElementSource isource;
  input Integer iIndex;
  input HashTableExpToIndex.HashTable iHt;
  input array<tuple<BackendDAE.Equation,Integer>> IEqnsarray;
  input list<tuple<DAE.Exp,Integer,DAE.ElementSource>> iAcc;
  output DAE.Exp slast;
  output DAE.ElementSource osource;
  output Integer oIndex;
  output list<tuple<DAE.Exp,Integer,DAE.ElementSource>> oAcc;
algorithm
  (slast,osource,oIndex,oAcc) := matchcontinue(exp,isource,iIndex,iHt,IEqnsarray,iAcc)
    local
      DAE.Exp sb;
      Integer i,index;
      DAE.ElementSource source;
    case(_,_,_,_,_,_)
      equation
        i = BaseHashTable.get(exp,iHt);
        ((BackendDAE.EQUATION(scalar=DAE.CALL(expLst = {_,_,sb}),source=source),index)) = IEqnsarray[i];
        (sb,source,index,oAcc) = semiLinearOptimize3(sb,source,index,iHt,IEqnsarray,(exp,iIndex,source)::iAcc);
      then
        (sb,source,index,oAcc);
    case(_,_,_,_,_,_)
      then
        (exp,isource,iIndex,iAcc);         
  end matchcontinue;
end semiLinearOptimize3;

protected function semiLinearGetSA
"function: semiLinearGetSA
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input DAE.Exp key;
  input HashTableExpToIndex.HashTable iHt1;
  input list<DAE.Exp> iAcc;
  output list<DAE.Exp> oAcc;
algorithm
  oAcc := matchcontinue(key,iHt1,iAcc)
    case (_,_,_)
      equation
        _ = BaseHashTable.get(key,iHt1);
      then
        iAcc;
    case(_,_,_)
      then
        key::iAcc;
  end matchcontinue;
end semiLinearGetSA;

protected function semiLinearOptimize1
"function: semiLinearOptimize1
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input list<tuple<BackendDAE.Equation,Integer>> eqnslst;
  input Integer i;
  input HashTableExpToIndex.HashTable iHt;
  input HashTableExpToIndex.HashTable iHt1;
  output HashTableExpToIndex.HashTable oHt;
  output HashTableExpToIndex.HashTable oHt1;
algorithm
  (oHt,oHt1) := match(eqnslst,i,iHt,iHt1)
    local
     BackendDAE.Equation eqn;     
      list<tuple<BackendDAE.Equation,Integer>> rest;
      HashTableExpToIndex.HashTable ht,ht1;
      DAE.Exp sa,sb;
    case ({},_,_,_) then (iHt,iHt1);
    case ((eqn as BackendDAE.EQUATION(scalar=DAE.CALL(expLst = {_,sa,sb})),_)::rest,_,_,_)
      equation
        ht = BaseHashTable.add((sa,i), iHt);
        ht1 = BaseHashTable.add((sb,i), iHt1);
        (ht,ht1) = semiLinearOptimize1(rest,i+1,ht,ht1);
      then
        (ht,ht1);
  end match;
end semiLinearOptimize1;

protected function semiLinearSort
"function: semiLinearSort
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input  list<tuple<BackendDAE.Equation,Integer>> eqnslst;
  input  HashTableExpToIndex.HashTable iHt;
  input  Integer size;
  input  array<list<tuple<BackendDAE.Equation,Integer>>> iEqnsarray;
  output  array<list<tuple<BackendDAE.Equation,Integer>>> oEqnsarray;
algorithm
  oEqnsarray := matchcontinue(eqnslst,iHt,size,iEqnsarray)
    local
     BackendDAE.Equation eqn;
     Integer index,i;
     list<tuple<BackendDAE.Equation,Integer>> rest,eqns;
     HashTableExpToIndex.HashTable ht;
     DAE.Exp y;
     array<list<tuple<BackendDAE.Equation,Integer>>> eqnsarray;
    case ({},_,_,_) then iEqnsarray;
    case ((eqn as BackendDAE.EQUATION(exp=y),index)::rest,_,_,_)
      equation
        i = BaseHashTable.get(y,iHt);
        eqns = iEqnsarray[i];
        eqnsarray = arrayUpdate(iEqnsarray,i,(eqn,index)::eqns);
      then
        semiLinearSort(rest,iHt,size,eqnsarray);
    case ((eqn as BackendDAE.EQUATION(exp=y),index)::rest,_,_,_)
      equation
        ht = BaseHashTable.add((y,size), iHt);
        // expand if necesarray
        eqnsarray = Debug.bcallret3(intGt(size,arrayLength(iEqnsarray)), Util.arrayExpand,5, iEqnsarray, {},iEqnsarray);
        eqnsarray = arrayUpdate(eqnsarray,size,{(eqn,index)});
      then
        semiLinearSort(rest,ht,size+1,eqnsarray);
  end matchcontinue;
end semiLinearSort;

protected function semiLinearSort1
"function: semiLinearSort1
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input  list<list<tuple<BackendDAE.Equation,Integer>>> eqnslstlst;
  input  Integer size;
  input  array<list<tuple<BackendDAE.Equation,Integer>>> iEqnsarray;
  output  array<list<tuple<BackendDAE.Equation,Integer>>> oEqnsarray;
algorithm
  oEqnsarray := match(eqnslstlst,size,iEqnsarray)
    local
     Integer size1;
     tuple<BackendDAE.Equation,Integer> tpl;
     list<tuple<BackendDAE.Equation,Integer>> eqns;
     list<list<tuple<BackendDAE.Equation,Integer>>> rest;
     HashTableExpToIndex.HashTable ht;
     array<list<tuple<BackendDAE.Equation,Integer>>> eqnsarray;
    case ({},_,_) then iEqnsarray;
    case ((tpl::{})::rest,_,_)
      equation
        // expand if necesarray
        eqnsarray = Debug.bcallret3(intGt(size,arrayLength(iEqnsarray)), Util.arrayExpand,5, iEqnsarray, {},iEqnsarray);
        eqnsarray = arrayUpdate(eqnsarray,size,{tpl});
      then
        semiLinearSort1(rest,size+1,eqnsarray);
    case (eqns::rest,_,_)
      equation
        ht = HashTableExpToIndex.emptyHashTable();
        (size1,eqnsarray) = semiLinearSort2(eqns,ht,size,iEqnsarray);
      then
        semiLinearSort1(rest,size1,eqnsarray);
  end match;
end semiLinearSort1;

protected function semiLinearSort2
"function: semiLinearSort2
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input  list<tuple<BackendDAE.Equation,Integer>> eqnslst;
  input  HashTableExpToIndex.HashTable iHt;
  input  Integer size;
  input  array<list<tuple<BackendDAE.Equation,Integer>>> iEqnsarray;
  output  Integer osize;
  output  array<list<tuple<BackendDAE.Equation,Integer>>> oEqnsarray;
algorithm
  (osize,oEqnsarray) := matchcontinue(eqnslst,iHt,size,iEqnsarray)
    local
     BackendDAE.Equation eqn;
     Integer index,i;
     list<tuple<BackendDAE.Equation,Integer>> rest,eqns;
     HashTableExpToIndex.HashTable ht;
     DAE.Exp x;
     array<list<tuple<BackendDAE.Equation,Integer>>> eqnsarray;
    case ({},_,_,_) then (size,iEqnsarray);
    case ((eqn as BackendDAE.EQUATION(scalar=DAE.CALL(expLst = x::_)),index)::rest,_,_,_)
      equation
        i = BaseHashTable.get(x,iHt);
        eqns = iEqnsarray[i];
        eqnsarray = arrayUpdate(iEqnsarray,i,(eqn,index)::eqns);
        (i,eqnsarray) = semiLinearSort2(rest,iHt,size,eqnsarray);
      then
        (i,eqnsarray);
    case ((eqn as BackendDAE.EQUATION(scalar=DAE.CALL(expLst = x::_)),index)::rest,_,_,_)
      equation
        ht = BaseHashTable.add((x,size), iHt);
        // expand if necesarray
        eqnsarray = Debug.bcallret3(intGt(size,arrayLength(iEqnsarray)), Util.arrayExpand,5, iEqnsarray, {},iEqnsarray);
        eqnsarray = arrayUpdate(eqnsarray,size,{(eqn,index)});
        (i,eqnsarray) = semiLinearSort2(rest,ht,size+1,eqnsarray);
      then
        (i,eqnsarray);
  end matchcontinue;
end semiLinearSort2;

protected function simplifysemiLinearFinder
"function: simplifysemiLinearFinder
  author: Frenkel TUD 2012-08
  helper for simplifysemiLinear"
  input tuple<BackendDAE.Equation,tuple<list<tuple<BackendDAE.Equation,Integer>>,Integer,Boolean>> inTpl;
  output tuple<BackendDAE.Equation,tuple<list<tuple<BackendDAE.Equation,Integer>>,Integer,Boolean>> outTpl;
algorithm
  outTpl:=  
  matchcontinue (inTpl)
    local 
      BackendDAE.Equation eqn;
      list<tuple<BackendDAE.Equation,Integer>> eqnslst;
      Integer index;
      Boolean b;
      DAE.Exp x,y,sa,sb;
      DAE.ElementSource source;
      Absyn.Path path;
      DAE.CallAttributes attr;
      Boolean diffed;
    // 0 = semiLinear(0,sa,sb) -> sa=sb
    case ((BackendDAE.EQUATION(exp=y,scalar=DAE.CALL(path = Absyn.IDENT("semiLinear"), expLst = {x,sa,sb}),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        true = Expression.isZero(y);
        true = Expression.isZero(x);
      then ((BackendDAE.EQUATION(sa,sb,source,diffed),(eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.CALL(path = Absyn.IDENT("semiLinear"), expLst = {x,sa,sb}),scalar=y,source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        true = Expression.isZero(y);
        true = Expression.isZero(x);
      then ((BackendDAE.EQUATION(sa,sb,source,diffed),(eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=y,scalar=DAE.UNARY(exp=DAE.CALL(path = Absyn.IDENT("semiLinear"), expLst = {x,sa,sb})),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        true = Expression.isZero(y);
        true = Expression.isZero(x);
      then ((BackendDAE.EQUATION(sa,sb,source,diffed),(eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.UNARY(exp=DAE.CALL(path = Absyn.IDENT("semiLinear"), expLst = {x,sa,sb})),scalar=y,source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        true = Expression.isZero(y);
        true = Expression.isZero(x);
      then ((BackendDAE.EQUATION(sa,sb,source,diffed),(eqnslst,index+1,true)));
    // y = -semiLinear(-x,sb,sa) -> y = semiLinear(x,sa,sb)
    case ((BackendDAE.EQUATION(exp=y,scalar=DAE.UNARY(exp=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr)),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.UNARY(exp=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr)),scalar=y,source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    // -y = semiLinear(-x,sb,sa) -> y = semiLinear(x,sa,sb)
    case ((BackendDAE.EQUATION(exp=DAE.UNARY(exp=y),scalar=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr),scalar=DAE.UNARY(exp=y),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    // y = semiLinear(-x,sb,sa) -> -y = semiLinear(x,sa,sb)
    case ((BackendDAE.EQUATION(exp=y,scalar=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        y = Expression.negate(y);
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.CALL(path = path as Absyn.IDENT("semiLinear"), expLst = {DAE.UNARY(exp=x),sb,sa},attr=attr),scalar=y,source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        y = Expression.negate(y);
        eqn = BackendDAE.EQUATION(y,DAE.CALL(path,{x,sa,sb},attr),source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));        
    // y = semiLinear(x,sa,sb)
    case ((eqn as BackendDAE.EQUATION(scalar=DAE.CALL(path =Absyn.IDENT("semiLinear"))),(eqnslst,index,_)))
      equation
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((eqn as BackendDAE.EQUATION(exp=DAE.CALL(path =Absyn.IDENT("semiLinear"))),(eqnslst,index,_)))
      equation
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=y,scalar=DAE.UNARY(exp= x as DAE.CALL(path = Absyn.IDENT("semiLinear"))),source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        y = Expression.negate(y);
        eqn = BackendDAE.EQUATION(y,x,source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));
    case ((BackendDAE.EQUATION(exp=DAE.UNARY(exp= x as DAE.CALL(path = Absyn.IDENT("semiLinear"))),scalar=y,source=source,differentiated=diffed),(eqnslst,index,_)))
      equation
        y = Expression.negate(y);
        eqn = BackendDAE.EQUATION(y,x,source,diffed);
        Debug.fcall(Flags.SEMILINEAR,BackendDump.debugStrEqnStr,("Found semiLinear ",eqn,"\n"));
      then ((eqn,((eqn,index)::eqnslst,index+1,true)));

    case ((eqn,(eqnslst,index,b))) then ((eqn,(eqnslst,index+1,b)));
  end matchcontinue;
end simplifysemiLinearFinder;

/*
 * check for derivatives of inputs
 *
 */
public function inputDerivativesUsed "function inputDerivativesUsed
  checks if der(input) is used and report a warning/error.
  author: Frenkel TUD 2012-10"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,inputDerivativesUsedWork,false);
end inputDerivativesUsed;

protected function inputDerivativesUsedWork "function inputDerivativesUsedWork
  author: Frenkel TUD 2012-10"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) := 
    matchcontinue(isyst,sharedChanged)
    local
      BackendDAE.Variables orderedVars "orderedVars ; ordered Variables, only states and alg. vars" ;
      BackendDAE.EquationArray orderedEqs "orderedEqs ; ordered Equations" ;
      Option<BackendDAE.IncidenceMatrix> m;
      Option<BackendDAE.IncidenceMatrixT> mT;
      BackendDAE.Matching matching;
      BackendDAE.Shared shared;
      list<DAE.Exp> explst;
      String s;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared, _))
      equation
        ((_,explst as _::_)) = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(orderedEqs,traverserinputDerivativesUsed,(BackendVariable.daeKnVars(shared),{}));
        s = stringDelimitList(List.map(explst,ExpressionDump.printExpStr),"\n");
        Error.addMessage(Error.DERIVATIVE_INPUT,{s});
      then
        (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared,true));
    else
      (isyst,sharedChanged);
  end matchcontinue;
end inputDerivativesUsedWork;

protected function traverserinputDerivativesUsed "function traverserinputDerivativesUsed
  author: Frenkel TUD 2012-10"
  input tuple<DAE.Exp,tuple<BackendDAE.Variables,list<DAE.Exp>>> itpl;
  output tuple<DAE.Exp,tuple<BackendDAE.Variables,list<DAE.Exp>>> outTpl;
protected
  DAE.Exp e;
  tuple<BackendDAE.Variables,list<DAE.Exp>> tpl;
algorithm
  (e,tpl) := itpl;
  outTpl := Expression.traverseExpTopDown(e,traverserExpinputDerivativesUsed,tpl);
end traverserinputDerivativesUsed;

protected function traverserExpinputDerivativesUsed "function traverserExpinputDerivativesUsed
  author: Frenkel TUD 2012-10"
  input tuple<DAE.Exp,tuple<BackendDAE.Variables,list<DAE.Exp>>> tpl;
  output tuple<DAE.Exp,Boolean,tuple<BackendDAE.Variables,list<DAE.Exp>>> outTpl;
algorithm
  outTpl := matchcontinue(tpl)
    local
      BackendDAE.Variables vars;
      DAE.Type tp;
      DAE.Exp e,zero;
      DAE.ComponentRef cr;
      BackendDAE.Var var;
      list<DAE.Exp> explst;
    case((e as DAE.CALL(path=Absyn.IDENT(name = "der"),expLst={DAE.CALL(path=Absyn.IDENT(name = "der"),expLst={DAE.CREF(componentRef=cr,ty=tp)})}),(vars,explst)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, vars);
        true = BackendVariable.isVarOnTopLevelAndInput(var);
      then
        ((e,false,(vars,e::explst)));
    case((e as DAE.CALL(path=Absyn.IDENT(name = "der"),expLst={DAE.CREF(componentRef=cr,ty=tp)}),(vars,explst)))
      equation
        (var::{},_) = BackendVariable.getVar(cr, vars);
        true = BackendVariable.isVarOnTopLevelAndInput(var);
      then
        ((e,false,(vars,e::explst)));
    case ((e,(vars,explst))) then ((e,true,(vars,explst)));
  end matchcontinue;
end traverserExpinputDerivativesUsed;


/*  
 * remove constants stuff
 *
 */ 
public function removeConstants
"function: removeConstants
  author Frenkel TUD"
  input BackendDAE.BackendDAE dae;
  output BackendDAE.BackendDAE odae;
algorithm
  odae := match (dae)
    local
      DAE.FunctionTree funcs;
      BackendDAE.Variables knvars,exobj,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendVarTransform.VariableReplacements repl;
      BackendDAE.BackendDAEType btp;
      BackendDAE.EqSystems systs;
      list<BackendDAE.Equation> lsteqns;
      Boolean b;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)))
      equation
        repl = BackendVarTransform.emptyReplacements();
        repl = BackendVariable.traverseBackendDAEVars(knvars,removeConstantsFinder,repl);
        Debug.fcall(Flags.DUMP_CONST_REPL, BackendVarTransform.dumpReplacements, repl);
        (knvars,(repl,_)) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,replaceFinalVarTraverser,(repl,0));
        lsteqns = BackendEquation.equationList(remeqns);
        (lsteqns,b) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        remeqns = Debug.bcallret1(b,BackendEquation.listEquation,lsteqns,remeqns);
        lsteqns = BackendEquation.equationList(inieqns);
        (lsteqns,b) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        inieqns = Debug.bcallret1(b,BackendEquation.listEquation,lsteqns,inieqns);
        systs = List.map1(systs,removeConstantsWork,repl);
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
  end match;
end removeConstants;

protected function removeConstantsWork
"function: removeConstantsWork
  author Frenkel TUD"
  input BackendDAE.EqSystem isyst;
  input BackendVarTransform.VariableReplacements repl;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,repl)
    local
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns,eqns1;
      list<BackendDAE.Equation> eqns_1,lsteqns;
      Boolean b;
      BackendDAE.EqSystem syst;
      BackendDAE.StateSets stateSets;      
    case (BackendDAE.EQSYSTEM(orderedVars=vars,orderedEqs=eqns,stateSets=stateSets),_)
      equation
        (vars,_) = BackendVariable.traverseBackendDAEVarsWithUpdate(vars,replaceFinalVarTraverser,(repl,0));
        lsteqns = BackendEquation.equationList(eqns);
        (eqns_1,b) = BackendVarTransform.replaceEquations(lsteqns, repl,NONE());
        eqns1 = Debug.bcallret1(b,BackendEquation.listEquation,eqns_1,eqns);
        syst = Util.if_(b,BackendDAE.EQSYSTEM(vars,eqns1,NONE(),NONE(),BackendDAE.NO_MATCHING(),stateSets),isyst);
      then
        syst;
  end match;
end removeConstantsWork;

protected function removeConstantsFinder
"author: Frenkel TUD 2012-10"
 input tuple<BackendDAE.Var, BackendVarTransform.VariableReplacements> inTpl;
 output tuple<BackendDAE.Var, BackendVarTransform.VariableReplacements> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v;
      BackendVarTransform.VariableReplacements repl,repl_1;
      DAE.ComponentRef varName;
      DAE.Exp exp;
    case ((v as BackendDAE.VAR(varName=varName,varKind=BackendDAE.CONST(),bindExp=SOME(exp)),repl))
      equation
        repl_1 = BackendVarTransform.addReplacement(repl, varName, exp,NONE());
      then ((v,repl_1));
    case _ then inTpl;
  end matchcontinue;
end removeConstantsFinder;


/*
 * reaplace edge and change with (b and not pre(b)) and (v <> pre(v) 
 *
 */
public function replaceEdgeChange "function replaceEdgeChange
  replace 
  edge(b) = b and not pre(b)
  change(b) = v <> pre(v)
  author: Frenkel TUD 2012-11"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  (outDAE,_) := BackendDAEUtil.mapEqSystemAndFold(inDAE,replaceEdgeChange0,false);
  outDAE := replaceEdgeChangeShared(outDAE);
end replaceEdgeChange;

protected function replaceEdgeChange0 "function replaceEdgeChange0
  author: Frenkel TUD 2012-11"
  input BackendDAE.EqSystem isyst;
  input tuple<BackendDAE.Shared,Boolean> sharedChanged;
  output BackendDAE.EqSystem osyst;
  output tuple<BackendDAE.Shared,Boolean> osharedChanged;
algorithm
  (osyst,osharedChanged) := 
    matchcontinue(isyst,sharedChanged)
    local
      BackendDAE.Variables orderedVars;
      BackendDAE.EquationArray orderedEqs;
      Option<BackendDAE.IncidenceMatrix> m;
      Option<BackendDAE.IncidenceMatrixT> mT;
      BackendDAE.Matching matching;
      BackendDAE.Shared shared;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared, _))
      equation
        _ = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(orderedEqs,traverserreplaceEdgeChange,false);
      then
        (BackendDAE.EQSYSTEM(orderedVars,orderedEqs,m,mT,matching,stateSets),(shared,true));
    else
      (isyst,sharedChanged);
  end matchcontinue;
end replaceEdgeChange0;

protected function traverserreplaceEdgeChange "function 
  author: Frenkel TUD 2012-11"
  input tuple<DAE.Exp,Boolean> itpl;
  output tuple<DAE.Exp,Boolean> outTpl;
protected
  DAE.Exp e;
  Boolean b;
algorithm
  (e,b) := itpl;
  outTpl := Expression.traverseExp(e,traverserExpreplaceEdgeChange,b);
end traverserreplaceEdgeChange;

protected function traverserExpreplaceEdgeChange "function traverserExpreplaceEdgeChange
  author: Frenkel TUD 2012-11"
  input tuple<DAE.Exp,Boolean> tpl;
  output tuple<DAE.Exp,Boolean> outTpl;
algorithm
  outTpl := matchcontinue(tpl)
    local
      DAE.Exp e;
      DAE.Type ty;
    // change(v) -> v <> pre(v)
    case((DAE.CALL(path=Absyn.IDENT(name = "change"),expLst={e}),_))
      equation
        ty = Expression.typeof(e);
      then
        ((DAE.RELATION(e,DAE.NEQUAL(ty),DAE.CALL(Absyn.IDENT("pre"),{e},DAE.CALL_ATTR(ty,false,true,DAE.NO_INLINE(),DAE.NO_TAIL())),-1,NONE()),true));
    // edge(b) = b and not pre(b)
    case((DAE.CALL(path=Absyn.IDENT(name = "edge"),expLst={e}),_))
      equation
        ty = Expression.typeof(e); 
      then
        ((DAE.LBINARY(e,DAE.AND(ty),DAE.LUNARY(DAE.NOT(ty),DAE.CALL(Absyn.IDENT("pre"),{e},DAE.CALL_ATTR(ty,false,true,DAE.NO_INLINE(),DAE.NO_TAIL())))),true));
    case _ then tpl;
  end matchcontinue;
end traverserExpreplaceEdgeChange;

protected function replaceEdgeChangeShared "function replaceEdgeChangeShared
  author: Frenkel TUD 2012-11"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE:= match (inDAE)
    local
      BackendDAE.Variables knvars,exobj,aliasVars;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcTree;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.EventInfo eventInfo;
      BackendDAE.BackendDAEType btp; 
      BackendDAE.EqSystems systs;  
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,eventInfo,eoc,btp,symjacs)))
      equation
        _ = BackendDAEUtil.traverseBackendDAEExpsEqnsWithUpdate(remeqns,traverserreplaceEdgeChange,false);
      then 
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,aliasVars,inieqns,remeqns,constrs,clsAttrs,cache,env,funcTree,eventInfo,eoc,btp,symjacs));
  end match;
end replaceEdgeChangeShared;


/*
 * optimize inital system
 *
 */

public function optimizeInitialSystem
"function: optimizeInitialSystem
  author Frenkel TUD 2012-08"
  input BackendDAE.BackendDAE inDAE;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (inDAE)
    local
      BackendDAE.EqSystems systs;
      BackendDAE.Variables knvars;
      BackendDAE.EquationArray inieqns;
      HashTable2.HashTable initalAliases;
      list<BackendDAE.Equation> eqnlst;
      Boolean optimizationfound;
    case (BackendDAE.DAE(systs,BackendDAE.SHARED(knownVars=knvars,initialEqs=inieqns)))
      equation
        // search 
        initalAliases = HashTable2.emptyHashTable();
        eqnlst = BackendEquation.equationList(inieqns);
        (eqnlst,initalAliases,optimizationfound) = optimizeInitialSystem1(eqnlst,knvars,initalAliases,{},false);
      then
        // do optimization
        optimizeInitialSystemWork(optimizationfound,inDAE,eqnlst,initalAliases);
  end match;
end optimizeInitialSystem;

protected function optimizeInitialSystemWork
"function: optimizeInitialSystemWork
  author Frenkel TUD 2012-08"
  input Boolean optimizationfound;
  input BackendDAE.BackendDAE inDAE;
  input list<BackendDAE.Equation> eqnlst;
  input HashTable2.HashTable initalAliases;
  output BackendDAE.BackendDAE outDAE;
algorithm
  outDAE := match (optimizationfound,inDAE,eqnlst,initalAliases)
    local
      BackendDAE.EqSystems systs;
      BackendDAE.Variables knvars,knvars1,exobj,av;
      BackendDAE.EquationArray remeqns,inieqns;
      array<DAE.Constraint> constrs;
      array<DAE.ClassAttributes> clsAttrs;
      Env.Cache cache;
      Env.Env env;      
      DAE.FunctionTree funcs;
      BackendDAE.EventInfo einfo;
      BackendDAE.ExternalObjectClasses eoc;
      BackendDAE.SymbolicJacobians symjacs;
      BackendDAE.BackendDAEType btp;
    case (true,BackendDAE.DAE(systs,BackendDAE.SHARED(knvars,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs)),_,_)
      equation
        (knvars1,(_,_)) = BackendVariable.traverseBackendDAEVarsWithUpdate(knvars,optimizeInitialAliasesFinder,(initalAliases,false));
        inieqns = BackendEquation.listEquation(eqnlst);
        systs= List.map1(systs,optimizeInitialAliases,initalAliases);
      then
        BackendDAE.DAE(systs,BackendDAE.SHARED(knvars1,exobj,av,inieqns,remeqns,constrs,clsAttrs,cache,env,funcs,einfo,eoc,btp,symjacs));
    case(false,_,_,_) 
      then inDAE;
  end match;
end optimizeInitialSystemWork;

protected function optimizeInitialSystem1"
  author: Frenkel TUD 2012-06"
  input list<BackendDAE.Equation> iEqns;
  input BackendDAE.Variables knvars;
  input HashTable2.HashTable iInitalAliases;
  input list<BackendDAE.Equation> iAcc;
  input Boolean iOptimizationfound;
  output list<BackendDAE.Equation> outEqsLst;
  output HashTable2.HashTable oInitalAliases;
  output Boolean oOptimizationfound;
algorithm
  (outEqsLst,oInitalAliases,oOptimizationfound) := matchcontinue (iEqns,knvars,iInitalAliases,iAcc,iOptimizationfound)
    local
      list<BackendDAE.Equation> eqnslst,eqnslst1;
      BackendDAE.Equation eqn;
      HashTable2.HashTable initalAliases;
      Boolean optimizationfound,negate;
      DAE.ComponentRef cr1,cr2;
      DAE.Exp e1,e2,e1_1,e2_1;
      list<DAE.Exp> ea1,ea2;

    case ({},_,_,_,_) then (listReverse(iAcc),iInitalAliases,iOptimizationfound);
    case ((eqn as BackendDAE.EQUATION(exp=e1,scalar=e2))::eqnslst,_,_,_,_)
      equation
        ((cr1,cr2,e1,e2,negate)::{}) = BackendEquation.aliasEquation(eqn);
        initalAliases = addInitialAlias(cr1,cr2,e1,e2,negate,knvars,iInitalAliases);
        (eqnslst1,initalAliases,optimizationfound) = optimizeInitialSystem1(eqnslst,knvars,initalAliases,iAcc,true);
       then
         (eqnslst1,initalAliases,optimizationfound);
    case (eqn::eqnslst,_,_,_,_)
      equation
        (eqnslst1,initalAliases,optimizationfound) = optimizeInitialSystem1(eqnslst,knvars,iInitalAliases,eqn::iAcc,iOptimizationfound);
       then
         (eqnslst1,initalAliases,optimizationfound);
  end matchcontinue;
end optimizeInitialSystem1;

protected function addInitialAlias
  input DAE.ComponentRef cr1;
  input DAE.ComponentRef cr2;
  input DAE.Exp e1;
  input DAE.Exp e2;
  input Boolean negate;
  input BackendDAE.Variables knvars;
  input HashTable2.HashTable iInitalAliases;
  output HashTable2.HashTable oInitalAliases;
algorithm
  oInitalAliases := matchcontinue(cr1,cr2,e1,e2,negate,knvars,iInitalAliases)
    local
      HashTable2.HashTable initalAliases;
      DAE.Exp e;  
    case(_,_,_,_,_,_,_)
      equation
        (_::_,_) = BackendVariable.getVar(cr2, knvars);
        e = Debug.bcallret1(negate, Expression.negate, e2, e2);
        initalAliases = BaseHashTable.add((cr1,e),iInitalAliases);
        Debug.fcall(Flags.DUMPOPTINIT,BackendDump.debugStrCrefStrExpStr,("Found initial Alias ",cr1," = ",e,"\n"));
      then
        initalAliases;
    case(_,_,_,_,_,_,_)
      equation
        (_::_,_) = BackendVariable.getVar(cr1, knvars);
        e = Debug.bcallret1(negate, Expression.negate, e1, e1);
        initalAliases = BaseHashTable.add((cr2,e),iInitalAliases);
        Debug.fcall(Flags.DUMPOPTINIT,BackendDump.debugStrCrefStrExpStr,("Found initial Alias ",cr2," = ",e,"\n"));
      then
        initalAliases;
  end matchcontinue;
end addInitialAlias;

protected function optimizeInitialAliases
"function: optimizeInitialAliases
  author Frenkel TUD 2012-08"
  input BackendDAE.EqSystem isyst;
  input HashTable2.HashTable initalAliases;
  output BackendDAE.EqSystem osyst;
algorithm
  osyst := match (isyst,initalAliases)
    local
      Option<BackendDAE.IncidenceMatrix> m,mT;
      BackendDAE.Variables vars;
      BackendDAE.EquationArray eqns;
      BackendDAE.Matching matching;
      Boolean b;
      BackendDAE.EqSystem syst;
      BackendDAE.StateSets stateSets;
    case (BackendDAE.EQSYSTEM(vars,eqns,m,mT,matching,stateSets),_)
      equation
        (vars,(_,b)) = BackendVariable.traverseBackendDAEVarsWithUpdate(vars,optimizeInitialAliasesFinder,(initalAliases,false));
        syst = Util.if_(b,BackendDAE.EQSYSTEM(vars,eqns,m,mT,matching,stateSets),isyst);
      then
        syst;
  end match;
end optimizeInitialAliases;

protected function optimizeInitialAliasesFinder
"author: Frenkel TUD 2011-03"
 input tuple<BackendDAE.Var, tuple<HashTable2.HashTable,Boolean>> inTpl;
 output tuple<BackendDAE.Var, tuple<HashTable2.HashTable,Boolean>> outTpl;
algorithm
  outTpl:=
  matchcontinue (inTpl)
    local
      BackendDAE.Var v;
      HashTable2.HashTable initalAliases;
      DAE.ComponentRef varName;
      DAE.Exp exp;
    case ((v as BackendDAE.VAR(varName=varName),(initalAliases,_)))
      equation
        exp = BaseHashTable.get(varName,initalAliases);
        v = BackendVariable.setVarStartValue(v, exp);
        v = BackendVariable.setVarFixed(v, true);
        Debug.fcall(Flags.DUMPOPTINIT,BackendDump.debugStrCrefStrExpStr,("Set Var ",varName," (start= ",exp,", fixed=true)\n"));
      then ((v,(initalAliases,true)));
    case _ then inTpl;
  end matchcontinue;
end optimizeInitialAliasesFinder;

end BackendDAEOptimize;
