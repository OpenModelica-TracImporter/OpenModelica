/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2014, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
 * ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from OSMC, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

function der "Derivative of the input expression"
  input Real x(unit="'p");
  output Real dx(unit="'p/s");
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'der()'\">der()</a>
</html>"));
end der;

impure function initial "True if in initialization phase"
  output Boolean isInitial;
external "builtin";
annotation(__OpenModelica_Impure=true, Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'initial()'\">initial()</a>
</html>"));
end initial;

impure function terminal "True after successful analysis"
  output Boolean isTerminal;
external "builtin";
annotation(__OpenModelica_Impure=true, Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'terminal()'\">terminal()</a>
</html>"));
end terminal;

type AssertionLevel = enumeration(error, warning) annotation(__OpenModelica_builtin=true,
  Documentation(info="<html>Used by <a href=\"modelica://assert\">assert()</a></html>"));

function assert "Check an assertion condition"
  input Boolean condition;
  input String message;
  input AssertionLevel level = AssertionLevel.error;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'assert()'\">assert()</a>
</html>"));
end assert;

function constrain
  input Real i1;
  input Real i2;
  input Real i3;
  output Real o1;
external "builtin";
annotation(version="Dymola / MSL 1.6");
end constrain;

function ceil "Round a real number towards plus infinity"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'ceil()'\">ceil()</a>
</html>"));
end ceil;

function floor "Round a real number towards minus infinity"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'floor()'\">floor()</a>
</html>"));
end floor;

function integer "Round a real number towards minus infinity"
  input Real x;
  output Integer y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'integer()'\">integer()</a>
</html>"));
end integer;

function sqrt "Square root"
  input Real x(unit="'p");
  output Real y(unit="'p(1/2)");
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sqrt()'\">sqrt()</a>
</html>"));
end sqrt;

function sign "Sign of real or integer number"
  input Real v;
  output Integer _sign;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sign()'\">sign()</a>
</html>"));
/* We do this with external "builtin" for now. But maybe we should inline it instead...
  annotation(__OpenModelica_EarlyInline = true);
algorithm
  _sign := noEvent(if v > 0 then 1 else if v < 0 then -1 else 0);
 */
end sign;

function identity "Identity matrix of given size"
  input Integer arraySize;
  output Integer[arraySize,arraySize] outArray;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'identity()'\">identity()</a>
</html>"));
end identity;

function semiLinear
  input Real x;
  input Real positiveSlope;
  input Real negativeSlope;
  output Real result;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'semiLinear()'\">semiLinear()</a>
</html>"));
end semiLinear;

function edge "Indicate rising edge"
  input Boolean b;
  output Boolean edgeEvent;
  // TODO: Ceval parameters? Needed to remove the builtin handler
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'edge()'\">edge()</a>
</html>"));
end edge;

function sin "Sine"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sin()'\">sin()</a>
</html>"));
end sin;

function cos "Cosine"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'cos()'\">cos()</a>
</html>"));
end cos;

function tan "Tangent (u shall not be -pi/2, pi/2, 3*pi/2, ...)"
  input Real u;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'tan()'\">tan()</a>
</html>"));
end tan;

function sinh "Hyperbolic sine"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sinh()'\">sinh()</a>
</html>"));
end sinh;

function cosh "Hyperbolic cosine"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'cosh()'\">cosh()</a>
</html>"));
end cosh;

function tanh "Hyperbolic tangent"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'tanh()'\">tanh()</a>
</html>"));
end tanh;

function asin "Inverse sine (-1 <= u <= 1)"
  input Real u;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'asin()'\">asin()</a>
</html>"));
end asin;

function acos "Inverse cosine (-1 <= u <= 1)"
  input Real u;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'acos()'\">acos()</a>
</html>"));
end acos;

function atan "Inverse tangent"
  input Real x;
  output Real y;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'atan()'\">atan()</a>
</html>"));
end atan;

function atan2 "Four quadrant inverse tangent"
  input Real y;
  input Real x;
  output Real z;
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'atan2()'\">atan2()</a>
</html>"));
end atan2;

function exp "Exponential, base e"
  input Real x(unit="1");
  output Real y(unit="1");
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'exp()'\">exp()</a>
</html>"));
end exp;

function log "Natural (base e) logarithm (u shall be > 0)"
  input Real u(unit="1");
  output Real y(unit="1");
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'log()'\">log()</a>
</html>"));
end log;

function log10 "Base 10 logarithm (u shall be > 0)"
  input Real u(unit="1");
  output Real y(unit="1");
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'log10()'\">log10()</a>
</html>"));
end log10;

function homotopy
  input Real actual;
  input Real simplified;
  output Real outValue;
external "builtin"
annotation(version="Modelica 3.2",Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'homotopy()'\">homotopy()</a> (experimental implementation)
</html>"));
end homotopy;

function linspace "Real vector with equally spaced elements"
  input Real x1 "start";
  input Real x2 "end";
  input Integer n "number";
  output Real v[n];
algorithm
  // assert(n >= 2, "linspace requires n>=2 but got " + String(n));
  v := {x1 + (x2-x1)*(i-1)/(n-1) for i in 1:n};
  annotation(__OpenModelica_builtin=true,__OpenModelica_EarlyInline=true,Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'linspace()'\">linspace()</a>
</html>"));
end linspace;

function div = $overload(OpenModelica.Internal.intDiv,OpenModelica.Internal.realDiv)
  "Integer part of a division of two Real numbers"
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'div()'\">div()</a>
</html>"));

function mod = $overload(OpenModelica.Internal.intMod,OpenModelica.Internal.realMod)
  "Integer modulus of a division of two Real numbers"
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'mod()'\">mod()</a>
</html>"));

function rem = $overload(OpenModelica.Internal.intRem,OpenModelica.Internal.realRem)
  "Integer remainder of the division of two Real numbers"
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'rem()'\">rem()</a>
</html>"));

function abs = $overload(OpenModelica.Internal.intAbs,OpenModelica.Internal.realAbs)
  "Absolute value"
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'abs()'\">abs()</a>
</html>"));

function outerProduct "Outer product of two vectors"
  input Real[:] v1;
  input Real[:] v2;
  output Real[size(v1,1),size(v2,1)] o;
algorithm
  o := matrix(v1) * transpose(matrix(v2));
annotation(__OpenModelica_builtin=true,__OpenModelica_EarlyInline=true,preferredView="text",Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'outerProduct()'\">outerProduct()</a>
</html>"));
end outerProduct;

function cross "Cross product of two 3-vectors"
  input Real[3] x;
  input Real[3] y;
  output Real[3] z;
/* Not working due to problems with non-builtin overloaded functions? Maybe it works now. Maybe it's bad to inline due to evaluating the same element many times?
algorithm
  z := { x[2]*y[3]-x[3]*y[2] , x[3]*y[1]-x[1]*y[3] , x[1]*y[2]-x[2]*y[1] };
*/
external "builtin" cross(x,y,z);
  annotation(__OpenModelica_EarlyInline = true, preferredView="text",Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'cross()'\">cross()</a>
</html>"));
end cross;

function skew "The skew matrix associated with the vector"
  input Real[3] x;
  output Real[3,3] y;
external "builtin" skew(x,y);
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'skew()'\">skew()</a>
</html>"));
end skew;

// Dummy functions that can't be properly defined in Modelica, but used by
// SCodeFlatten to define which builtin functions exist (SCodeFlatten doesn't
// care how the functions are defined, only if they exist or not).

impure function delay "Delay expression"
  external "builtin";
  annotation(__OpenModelica_Impure=true, Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'delay()'\">delay()</a>
</html>"));
end delay;

function min "Returns the smallest element"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'min()'\">min()</a>
</html>"));
end min;

function max "Returns the largest element"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'max()'\">max()</a>
</html>"));
end max;

function sum "Sum of all array elements"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sum()'\">sum()</a>
</html>"));
end sum;

function product "Product of all array elements"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'product()'\">product()</a>
</html>"));
end product;

function transpose "Transpose a matrix"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'transpose()'\">transpose()</a>
</html>"));
end transpose;

function symmetric "Returns a symmetric matrix"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'symmetric()'\">symmetric()</a>
</html>"));
end symmetric;

function smooth "Indicate smoothness of expression"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'smooth()'\">smooth()</a>
</html>"));
end smooth;

function diagonal "Returns a diagonal matrix"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'diagonal()'\">diagonal()</a>
</html>"));
end diagonal;

function cardinality "Number of connectors in connection"
  input Real c;
  output Integer numOccurances;
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'cardinality()'\">cardinality()</a>
</html>"),version="Deprecated");
end cardinality;

function array "Constructs an array"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'array()'\">array()</a>
</html>"));
end array;

function zeros "Returns a zero array"
  input Integer n annotation(__OpenModelica_varArgs=true);
  output Integer o[:];
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'zeros()'\">zeros()</a>
</html>"));
end zeros;

function ones "Returns a one array"
  input Integer n annotation(__OpenModelica_varArgs=true);
  output Integer o[:];
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'ones()'\">ones()</a>
</html>"));
end ones;

function fill "Returns an array with all elements equal"
  input OpenModelica.Internal.BuiltinType s;
  input Integer n annotation(__OpenModelica_varArgs=true);
  output OpenModelica.Internal.BuiltinType o[:];
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'fill()'\">fill()</a>
</html>"));
end fill;

function noEvent "Turn off event triggering"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'noEvent()'\">noEvent()</a>
</html>"));
end noEvent;

function pre "Refer to left limit"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'pre()'\">pre()</a>
</html>"));
end pre;

function sample "Overloaded operator to either trigger time events or to convert between continuous-time and clocked-time representation"
external "builtin";
annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'sample()'\">sample()</a>
</html>"));
end sample;

function previous "Access previous value of a clocked variable"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'previous()'\">previous()</a>
</html>"));
end previous;

function hold "Conversion from clocked discrete-time to continuous time"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'hold()'\">hold()</a>
</html>"));
end hold;

impure function subSample "Conversion from faster clock to slower clock"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'subSample()'\">subSample()</a>
</html>"));
end subSample;

function superSample "Conversion from slower clock to faster clock"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'superSample()'\">superSample()</a>
</html>"));
end superSample;

function shiftSample "First activation of clock is shifted in time"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'shiftSample()'\">shiftSample()</a>
</html>"));
end shiftSample;

function backSample "First activation of clock is shifted in time before activation of u"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'backSample()'\">backSample()</a>
</html>"));
end backSample;

function noClock "Clock of y=Clock(u) is always inferred"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'noClock()'\">noClock()</a>
</html>"));
end noClock;

function interval "Returns the interval between the previous and present tick of the clock of its argument"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'interval()'\">interval()</a>
</html>"));
end interval;

function transition "Define state machine transition"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'transition()'\">transition()</a>
</html>"));
end transition;

function initialState "Define inital state of a state machine"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'initialState()'\">initialState()</a>
</html>"));
end initialState;

function activeState "Return true if instance of a state machine is active, otherwise false"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'activeState()'\">activeState()</a>
</html>"));
end activeState;

function ticksInState "Returns the number of clock ticks since a transition was made to the currently active state"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'ticksInState()'\">ticksInState()</a>
</html>"));
end ticksInState;

function timeInState "Returns the time duration as Real in [s] since a transition was made to the currently active state"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'ticksInState()'\">ticksInState()</a>
</html>"));
end timeInState;

function change "Indicate discrete variable changing"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'change()'\">change()</a>
</html>"));
end change;

function reinit "Reinitialize state variable"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'reinit()'\">reinit()</a>
</html>"));
end reinit;

function ndims "Number of array dimensions"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'ndims()'\">ndims()</a>
</html>"));
end ndims;

function size "Returns dimensions of an array"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'size()'\">size()</a>
</html>"));
end size;

function scalar "Returns a one-element array as scalar"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'scalar()'\">scalar()</a>
</html>"));
end scalar;

function vector "Returns an array as vector"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'vector()'\">vector()</a>
</html>"));
end vector;

function matrix "Returns the first two dimensions of an array as matrix"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'matrix()'\">matrix()</a>
</html>"));
end matrix;

function cat "Concatenate arrays along given dimension"
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'cat()'\">cat()</a>
</html>"));
end cat;

function rooted "Not yet standard Modelica, but in the MSL since 3-4 years now."
  external "builtin";
  annotation(Documentation(info="<html>
<p><b>Not yet standard Modelica, but in the MSL since 3-4 years now.</b></p>
<h4>Syntax</h4>
<blockquote>
<pre><b>rooted</b>(x)</pre>
</blockquote>
<h4>Description</h4>
<p>The operator \"rooted\" was introduced to improve efficiency:
A tool that constructs the graph with the Connections.branch/.root etc.
built-in operators has to cut the graph in order to arrive at \"spanning trees\".
If there is a statement \"Connections.branch(A,B)\", then \"rooted(A)\" returns true,
if \"A\" is closer to the root of the spanning tree as \"B\". Otherwise false is returned.
For the MultiBody library this allows to avoid unnecessary small linear systems of equations.
</p>
<h4>Known Bugs</h4>
<p>
OpenModelica, <b>rooted</b>(x) always returns true.
See <a href=\"https://trac.modelica.org/Modelica/ticket/95\">rooted ticket in the Modelica Trac</a> for details.
</p>
</html>"),version="Deprecated in the upcoming Modelica 3.2 rev2");
end rooted;

function actualStream
  external "builtin";
end actualStream;

function inStream
  external "builtin";
  annotation(Documentation(info="<html>
  See <a href=\"modelica://ModelicaReference.Operators.'inStream()'\">inStream()</a>
</html>"));
end inStream;

/* Extension for uncertainty computations */
record Distribution
  String name "the name of the distibution, e.g \"normal\" ";
  Real params[:] "parameter values for the specified distribution, e.g {0,0.1} for a normal distribution";
  String paramNames[:/*should be size(params,1) but doesn't work, cb issue #1682*/] "the parameter names for the specified distribution, e.g {\"my\",\"sigma\"} for a normal distribution";
end Distribution;

record Correlation "defines correlation between two uncertainty variables"
   Real v1 "first variable";
   Real v2 "second variable";
   Real c "correlation value";
end Correlation;


encapsulated package Connections
  import OpenModelica.$Code.VariableName;

  function branch
    input VariableName node1;
    input VariableName node2;
    external "builtin";
  end branch;

  function root
    input VariableName node;
    external "builtin";
  end root;

  function potentialRoot
    input VariableName node;
    parameter input Integer priority = 0;
    external "builtin";
  end potentialRoot;

  function isRoot
    input VariableName node;
    output Boolean isroot;
    external "builtin";
  end isRoot;

  function uniqueRoot
    input VariableName root;
    input String message = "";
    external "builtin";
  end uniqueRoot;

  function uniqueRootIndices
    input VariableName[:] roots;
    input VariableName[:] nodes;
    input String message = "";
    output Integer[size(roots, 1)] rootIndices;
    // adrpo: I would like an assert here: size(nodes) <= size (roots)
    external "builtin";
  end uniqueRootIndices;
end Connections;

encapsulated package Subtask
  type SamplingType = enumeration(Disabled, Continuous, Periodic);

  function decouple
    external "builtin";
  end decouple;

  function activated
    output Boolean activated;
    external "builtin";
  end activated;

  function lastInterval
    external "builtin";
  end lastInterval;
end Subtask;

impure function print "Prints to stdout, useful for debugging."
  input String str;
external "builtin";
annotation(__OpenModelica_Impure=true, version="OpenModelica extension");
end print;

function classDirectory "Non-standard operator"
  output String str;
external "builtin";
annotation(Documentation(info="<html>
<p>classDirectory() is a <b>non-standard operator</b> that was replaced by <a href=\"modelica://Modelica.Utilities.Files.loadResource\">Modelica.Utilities.Files.loadResource(uri)</a> before it was added to the language specification.</p>
<p>Returns the directory of the file where the classDirectory() call came from.</p>
</html>"),version="Dymola / MSL 2.2.1");
end classDirectory;

function getInstanceName
  output String instanceName;
external "builtin";
  annotation(Documentation(info="<html>
<h4>
Modelica definition:
</h4>
<p>
Returns a string with the name of the model/block that is simulated,
appended with the fully qualified name of the instance in which this
function is called.
</p>

<p>
If MyLib.Vehicle is simulated, the call of <b>getInstanceName()</b> might return:
  <em>Vehicle.engine.controller</em>
</p>
<p>
Outside of a model or block, the return value is not specified.
</p>

<h4>
OpenModelica specifics:
</h4>

<p>
When OpenModelica does not have a prefix (e.g. in functions or packages),
it returns the name of the function or package.
</p>

<p>
If no class was being simulated, the last simulated class or a default will be used
(applicable for functions called from the scripting environment).
</p>
</html>
"),version="Modelica 3.3");
end getInstanceName;

function spatialDistribution "Not yet implemented"
  input Real in0;
  input Real x;
  input Real initialPoints[:];
  input Real initialValues[size(initialPoints)];
  input Real in1;
  input Boolean positiveVelocity;
  output Real val;
external "builtin";
annotation(version="Modelica 3.3");
end spatialDistribution;

/* Actually contains more...
record SimulationResult
  String resultFile;
  String simulationOptions;
  String messages;
end SimulationResult; */

encapsulated package OpenModelica "OpenModelica internal defintions and scripting functions"

type $Code "Code quoting is not a uniontype yet because that would require enabling MetaModelica extensions in the regular compiler.
Besides, it has special semantics."

type Expression "An expression of some kind" end Expression;
type TypeName "A path, for example the name of a class, e.g. A.B.C or .A.B" end TypeName;
type VariableName "A variable name, e.g. a.b or a[1].b[3].c" end VariableName;
type VariableNames "An array of variable names, e.g. {a.b,a[1].b[3].c}, or a single VariableName" end VariableNames;

end $Code;

function threadData
  output ThreadData threadData;
protected
  record ThreadData
  end ThreadData;
external "builtin" annotation(Documentation(info="<html>
<p>Used to access thread-specific data in external functions.</p>
</html>"));
end threadData;

package Internal "Contains internal implementations, e.g. overloaded builtin functions"

  type BuiltinType "Integer,Real,String,enumeration or array of some kind"
  end BuiltinType;

  function intAbs
    input Integer v;
    output Integer o;
  external "builtin" o=abs(v);
  annotation(preferredView="text");
  end intAbs;

  function realAbs
    input Real v;
    output Real o;
  external "builtin" o=abs(v);
  annotation(preferredView="text");
  end realAbs;

  function intDiv
    input Integer x;
    input Integer y;
    output Integer z;
  external "builtin" z=div(x,y);
  annotation(preferredView="text");
  end intDiv;

  function realDiv
    input Real x;
    input Real y;
    output Real z;
  external "builtin" z=div(x,y);
  annotation(preferredView="text");
  end realDiv;

  function intMod
    input Integer x;
    input Integer y;
    output Integer z;
  external "builtin" z=mod(x,y);
  annotation(preferredView="text");
  end intMod;

  function realMod
    input Real x;
    input Real y;
    output Real z;
  external "builtin" z=mod(x,y);
  annotation(preferredView="text");
  end realMod;

  function intRem
    input Integer x;
    input Integer y;
    output Integer z;
  algorithm
    z := x - (div(x, y) * y);
    annotation(preferredView="text", __OpenModelica_EarlyInline=true);
  end intRem;

  function realRem
    input Real x;
    input Real y;
    output Real z;
  algorithm
    z := x - (div(x, y) * y);
    annotation(preferredView="text", __OpenModelica_EarlyInline=true);
  end realRem;

  package Architecture
    function numBits
      output Integer numBit;
      external "builtin";
    end numBits;
    function integerMax
      output Integer max;
      external "builtin";
    end integerMax;
  end Architecture;

annotation(preferredView="text");
end Internal;

package Scripting

import OpenModelica.$Code.Expression;
import OpenModelica.$Code.TypeName;
import OpenModelica.$Code.VariableName;
import OpenModelica.$Code.VariableNames;

record CheckSettingsResult
  String OPENMODELICAHOME, OPENMODELICALIBRARY, OMC_PATH, SYSTEM_PATH, OMDEV_PATH;
  Boolean OMC_FOUND;
  String MODELICAUSERCFLAGS, WORKING_DIRECTORY;
  Boolean CREATE_FILE_WORKS, REMOVE_FILE_WORKS;
  String OS, SYSTEM_INFO, SENDDATALIBS, C_COMPILER, C_COMPILER_VERSION;
  Boolean C_COMPILER_RESPONDING, HAVE_CORBA;
  String CONFIGURE_CMDLINE;
annotation(preferredView="text");
end CheckSettingsResult;

package Internal

package Time

/* From CevalScript */
constant Integer RT_CLOCK_SIMULATE_TOTAL = 8;
constant Integer RT_CLOCK_SIMULATE_SIMULATION = 9;
constant Integer RT_CLOCK_BUILD_MODEL = 10;
constant Integer RT_CLOCK_EXECSTAT_MAIN = 11;
constant Integer RT_CLOCK_EXECSTAT_BACKEND_MODULES = 12;
constant Integer RT_CLOCK_FRONTEND = 13;
constant Integer RT_CLOCK_BACKEND = 14;
constant Integer RT_CLOCK_SIMCODE = 15;
constant Integer RT_CLOCK_LINEARIZE = 16;
constant Integer RT_CLOCK_TEMPLATES = 17;
constant Integer RT_CLOCK_UNCERTAINTIES = 18;
constant Integer RT_CLOCK_USER_RESERVED = 19;

function readableTime
  input Real sec;
  output String str;
protected
  Integer tmp,min,hr;
algorithm
  tmp := mod(integer(sec),60);
  min := div(integer(sec),60);
  hr := div(min,60);
  min := mod(min,60);
  str := (if hr>0 then String(hr) + "h" else "") + (if min>0 then String(min) + "m" else "") + String(tmp) + "s";
end readableTime;

function timerTick
  input Integer index;
external "builtin";
annotation(Documentation(info="<html>
Starts the internal timer with the given index.
</html>"),preferredView="text");
end timerTick;

function timerTock
  input Integer index;
  output Real elapsed;
external "builtin";
annotation(Documentation(info="<html>
Reads the internal timer with the given index.
</html>"),preferredView="text");
end timerTock;

function timerClear
  input Integer index;
external "builtin";
annotation(Documentation(info="<html>
Clears the internal timer with the given index.
</html>"),preferredView="text");
end timerClear;

end Time;

type FileType = enumeration(NoFile, RegularFile, Directory, SpecialFile);

function stat
  input String name;
  output FileType fileType;
external "C" fileType = ModelicaInternal_stat(name) annotation(Library="ModelicaExternalC");
end stat;

end Internal;

function checkSettings "Display some diagnostics."
  output CheckSettingsResult result;
external "builtin";
annotation(preferredView="text");
end checkSettings;

function loadFile "load file (*.mo) and merge it with the loaded AST."
  input String fileName;
  input String encoding := "UTF-8";
  input Boolean uses := true;
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html>
<p>Loads the given file using the given encoding.</p>
<p>
  Note that if the file basename is package.mo and the parent directory is the top-level class, the library structure is loaded as if loadModel(ClassName) was called.
  Uses-annotations are respected if uses=true.
  The main difference from loadModel is that loadFile appends this directory to the MODELICAPATH (for this call only).
</p>
</html>"), preferredView="text");
end loadFile;

function loadFiles "load files (*.mo) and merges them with the loaded AST."
  input String[:] fileNames;
  input String encoding := "UTF-8";
  input Integer numThreads := OpenModelica.Scripting.numProcessors();
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end loadFiles;

function reloadClass "reloads the file associated with the given (loaded class)"
  input TypeName name;
  input String encoding := "UTF-8";
  output Boolean success;
external "builtin";
annotation(preferredView="text",Documentation(info="<html>
<p>Given an existing, loaded class in the compiler, compare the time stamp of the loaded class with the time stamp (mtime) of the file it was loaded from. If these differ, parse the file and merge it with the AST.</p>
</html>"));
end reloadClass;

function loadString "Parses the data and merges the resulting AST with ithe
  loaded AST.
  If a filename is given, it is used to provide error-messages as if the string
was read in binary format from a file with the same name.
  The file is converted to UTF-8 from the given character set.

  NOTE: Encoding is deprecated as *ALL* strings are now UTF-8 encoded.
  "
  input String data;
  input String filename := "<interactive>";
  input String encoding := "UTF-8";
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end loadString;

function parseString
  input String data;
  input String filename := "<interactive>";
  output TypeName names[:];
external "builtin";
annotation(preferredView="text");
end parseString;

function parseFile
  input String filename;
  input String encoding := "UTF-8";
  output TypeName names[:];
external "builtin";
annotation(preferredView="text");
end parseFile;

function loadFileInteractiveQualified
  input String filename;
  input String encoding := "UTF-8";
  output TypeName names[:];
external "builtin";
annotation(preferredView="text");
end loadFileInteractiveQualified;

function loadFileInteractive
  input String filename;
  input String encoding := "UTF-8";
  output TypeName names[:];
external "builtin";
annotation(preferredView="text");
end loadFileInteractive;

impure function system "Similar to system(3). Executes the given command in the system shell."
  input String callStr "String to call: sh -c $callStr";
  input String outputFile := "" "The output is redirected to this file (unless already done by callStr)";
  output Integer retval "Return value of the system call; usually 0 on success";
external "builtin" annotation(__OpenModelica_Impure=true);
annotation(preferredView="text");
end system;

impure function system_parallel "Similar to system(3). Executes the given commands in the system shell, in parallel if omc was compiled using OpenMP."
  input String callStr[:] "String to call: sh -c $callStr";
  input Integer numThreads := numProcessors();
  output Integer retval[:] "Return value of the system call; usually 0 on success";
external "builtin" annotation(__OpenModelica_Impure=true);
annotation(preferredView="text");
end system_parallel;

function saveAll "save the entire loaded AST to file."
  input String fileName;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end saveAll;

function help "display the OpenModelica help text."
  input String topic := "topics";
  output String helpText;
external "builtin";
end help;

function clear "Clears everything: symboltable and variables."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end clear;

function clearProgram "Clears loaded ."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end clearProgram;

function clearVariables "Clear all user defined variables."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end clearVariables;

function generateHeader
  input String fileName;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end generateHeader;

function generateSeparateCode
  input TypeName className;
  input Boolean cleanCache := false "If true, the cache is reset between each generated package. This conserves memory at the cost of speed.";
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html><p>Under construction.</p>
</html>"),preferredView="text");
end generateSeparateCode;

function generateSeparateCodeDependencies
  input String stampSuffix := ".c" "Suffix to add to dependencies (often .c.stamp)";
  output String [:] dependencies;
external "builtin";
annotation(Documentation(info="<html><p>Under construction.</p>
</html>"),preferredView="text");
end generateSeparateCodeDependencies;

function generateSeparateCodeDependenciesMakefile
  input String filename "The file to write the makefile to";
  input String directory := "" "The relative path of the generated files";
  input String suffix := ".c" "Often .stamp since we do not update all the files";
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html><p>Under construction.</p>
</html>"),preferredView="text");
end generateSeparateCodeDependenciesMakefile;

function getLinker
  output String linker;
external "builtin";
annotation(preferredView="text");
end getLinker;

function setLinker
  input String linker;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setLinker;

function getLinkerFlags
  output String linkerFlags;
external "builtin";
annotation(preferredView="text");
end getLinkerFlags;

function setLinkerFlags
  input String linkerFlags;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setLinkerFlags;

function getCompiler "CC"
  output String compiler;
external "builtin";
annotation(preferredView="text");
end getCompiler;

function setCompiler "CC"
  input String compiler;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCompiler;

function setCFlags "CFLAGS"
  input String inString;
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html>
Sets the CFLAGS passed to the C-compiler. Remember to add -fPIC if you are on a 64-bit platform. If you want to see the defaults before you modify this variable, check the output of <a href=\"modelica://OpenModelica.Scripting.getCFlags\">getCFlags()</a>. ${SIM_OR_DYNLOAD_OPT_LEVEL} can be used to get a default lower optimization level for dynamically loaded functions. And ${MODELICAUSERCFLAGS} is nice to add so you can easily modify the CFLAGS later by using an environment variable.
</html>"),
  preferredView="text");
end setCFlags;

public function getCFlags "CFLAGS"
  output String outString;
external "builtin";
annotation(Documentation(info="<html>
See <a href=\"modelica://OpenModelica.Scripting.setCFlags\">setCFlags()</a> for details.
</html>"),
  preferredView="text");
end getCFlags;

function getCXXCompiler "CXX"
  output String compiler;
external "builtin";
annotation(preferredView="text");
end getCXXCompiler;

function setCXXCompiler "CXX"
  input String compiler;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCXXCompiler;

function verifyCompiler
  output Boolean compilerWorks;
external "builtin";
annotation(preferredView="text");
end verifyCompiler;

function setCompilerPath
  input String compilerPath;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCompilerPath;

function getCompileCommand
  output String compileCommand;
external "builtin";
annotation(preferredView="text");
end getCompileCommand;

function setCompileCommand
  input String compileCommand;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCompileCommand;

function setPlotCommand
  input String plotCommand;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setPlotCommand;

function getSettings
  output String settings;
algorithm
  settings :=
    "Compile command: " + getCompileCommand() + "\n" +
    "Temp folder path: " + getTempDirectoryPath() + "\n" +
    "Installation folder: " + getInstallationDirectoryPath() + "\n" +
    "Modelica path: " + getModelicaPath() + "\n";
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end getSettings;

function setTempDirectoryPath
  input String tempDirectoryPath;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setTempDirectoryPath;

function getTempDirectoryPath "Returns the current user temporary directory location."
  output String tempDirectoryPath;
external "builtin";
annotation(preferredView="text");
end getTempDirectoryPath;

function getEnvironmentVar "Returns the value of the environment variable."
  input String var;
  output String value "returns empty string on failure";
external "builtin";
annotation(preferredView="text");
end getEnvironmentVar;

function setEnvironmentVar
  input String var;
  input String value;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setEnvironmentVar;

function appendEnvironmentVar "Appends a variable to the environment variables list."
  input String var;
  input String value;
  output String result "returns \"error\" if the variable could not be appended";
algorithm
  result := if setEnvironmentVar(var,getEnvironmentVar(var)+value) then getEnvironmentVar(var) else "error";
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end appendEnvironmentVar;

function setInstallationDirectoryPath "Sets the OPENMODELICAHOME environment variable. Use this method instead of setEnvironmentVar."
  input String installationDirectoryPath;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setInstallationDirectoryPath;

function getInstallationDirectoryPath "This returns OPENMODELICAHOME if it is set; on some platforms the default path is returned if it is not set."
  output String installationDirectoryPath;
external "builtin";
annotation(preferredView="text");
end getInstallationDirectoryPath;

function setModelicaPath "The Modelica Library Path - MODELICAPATH in the language specification; OPENMODELICALIBRARY in OpenModelica."
  input String modelicaPath;
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html>
See <a href=\"modelica://OpenModelica.Scripting.loadModel\">loadModel()</a> for a description of what the MODELICAPATH is used for.
</html>"),
  preferredView="text");
end setModelicaPath;

function getModelicaPath "Get the Modelica Library Path."
  output String modelicaPath;
external "builtin";
annotation(Documentation(info="<html>
<p>The MODELICAPATH is list of paths to search when trying to  <a href=\"modelica://OpenModelica.Scripting.loadModel\">load a library</a>. It is a string separated by colon (:) on all OSes except Windows, which uses semicolon (;).</p>
<p>To override the default path (<a href=\"modelica://OpenModelica.Scripting.getModelicaPath\">getModelicaPath()</a>/lib/omlibrary/:~/.openmodelica/libraries/), set the environment variable OPENMODELICALIBRARY=...</p>
</html>"),
  preferredView="text");
end getModelicaPath;

function setCompilerFlags
  input String compilerFlags;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCompilerFlags;

function setDebugFlags "example input: failtrace,-noevalfunc"
  input String debugFlags;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+d=" + debugFlags);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setDebugFlags;

function clearDebugFlags
  "Resets all debug flags to their default values."
  output Boolean success;
  external "builtin";
  annotation(preferredView="text");
end clearDebugFlags;

function setPreOptModules "example input: removeFinalParameters,removeSimpleEquations,expandDerOperator"
  input String modules;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+preOptModules=" + modules);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setPreOptModules;

function setCheapMatchingAlgorithm "example input: 3"
  input Integer matchingAlgorithm;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+cheapmatchingAlgorithm=" + String(matchingAlgorithm));
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setCheapMatchingAlgorithm;

function getMatchingAlgorithm
  output String selected;
  external "builtin";
end getMatchingAlgorithm;

function getAvailableMatchingAlgorithms
  output String[:] allChoices;
  output String[:] allComments;
  external "builtin";
end getAvailableMatchingAlgorithms;

function setMatchingAlgorithm "example input: omc"
  input String matchingAlgorithm;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+matchingAlgorithm=" + matchingAlgorithm);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setMatchingAlgorithm;

function getIndexReductionMethod
  output String selected;
  external "builtin";
end getIndexReductionMethod;

function getAvailableIndexReductionMethods
  output String[:] allChoices;
  output String[:] allComments;
  external "builtin";
end getAvailableIndexReductionMethods;

function setIndexReductionMethod "example input: dynamicStateSelection"
  input String method;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+indexReductionMethod=" + method);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setIndexReductionMethod;

function setPostOptModules "example input: lateInline,inlineArrayEqn,removeSimpleEquations."
  input String modules;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+postOptModules=" + modules);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setPostOptModules;

function getTearingMethod
  output String selected;
  external "builtin";
end getTearingMethod;

function getAvailableTearingMethods
  output String[:] allChoices;
  output String[:] allComments;
  external "builtin";
end getAvailableTearingMethods;

function setTearingMethod "example input: omcTearing"
  input String tearingMethod;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+tearingMethod=" + tearingMethod);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setTearingMethod;

function setCommandLineOptions
  "The input is a regular command-line flag given to OMC, e.g. +d=failtrace or +g=MetaModelica"
  input String option;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setCommandLineOptions;

function getConfigFlagValidOptions
  "Returns the list of valid options for a string config flag, and the description strings for these options if available"
  input String flag;
  output String validOptions[:];
  output String mainDescription;
  output String descriptions[:];
external "builtin";
annotation(preferredView="text");
end getConfigFlagValidOptions;

function clearCommandLineOptions
  "Resets all command-line flags to their default values."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end clearCommandLineOptions;

function getVersion "Returns the version of the Modelica compiler."
  input TypeName cl := $TypeName(OpenModelica);
  output String version;
external "builtin";
annotation(preferredView="text");
end getVersion;

function regularFileExists
  input String fileName;
  output Boolean exists;
algorithm
  exists := Internal.stat(fileName) == Internal.FileType.RegularFile;
end regularFileExists;

function directoryExists
  input String dirName;
  output Boolean exists;
algorithm
  exists := Internal.stat(dirName) == Internal.FileType.Directory;
end directoryExists;

impure function readFile
  "The contents of the given file are returned.
  Note that if the function fails, the error message is returned as a string instead of multiple output or similar."
  input String fileName;
  output String contents;
external "builtin" annotation(__OpenModelica_Impure=true);
annotation(preferredView="text");
end readFile;

impure function writeFile
  "Write the data to file. Returns true on success."
  input String fileName;
  input String data;
  input Boolean append := false;
  output Boolean success;
external "builtin" annotation(__OpenModelica_Impure=true);
annotation(preferredView="text");
end writeFile;

impure function compareFilesAndMove
  input String newFile;
  input String oldFile;
  output Boolean success;
external "builtin" annotation(__OpenModelica_Impure=true,Documentation(info="<html>
<p>Compares <i>newFile</i> and <i>oldFile</i>. If they differ, overwrite <i>oldFile</i> with <i>newFile</i></p>
<p>Basically: test -f ../oldFile && cmp newFile oldFile || mv newFile oldFile</p>
</html>"));
end compareFilesAndMove;

impure function compareFiles
  input String file1;
  input String file2;
  output Boolean isEqual;
external "builtin" annotation(__OpenModelica_Impure=true,Documentation(info="<html>
<p>Compares <i>file1</i> and <i>file2</i> and returns true if their content is equal, otherwise false.</p>
</html>"));
end compareFiles;

impure function alarm
  input Integer seconds;
  output Integer previousSeconds;
external "builtin" annotation(__OpenModelica_Impure=true,Library = {"omcruntime"},Documentation(info="<html>
<p>Like <a href=\"http://linux.die.net/man/2/alarm\">alarm(2)</a>.</p>
</html>"));
end alarm;

function regex  "Sets the error buffer and returns -1 if the regex does not compile.

  The returned result is the same as POSIX regex():
  The first value is the complete matched string
  The rest are the substrings that you wanted.
  For example:
  regex(lorem,\" \\([A-Za-z]*\\) \\([A-Za-z]*\\) \",maxMatches=3)
  => {\" ipsum dolor \",\"ipsum\",\"dolor\"}
  This means if you have n groups, you want maxMatches=n+1
"
  input String str;
  input String re;
  input Integer maxMatches := 1 "The maximum number of matches that will be returned";
  input Boolean extended := true "Use POSIX extended or regular syntax";
  input Boolean caseInsensitive := false;
  output Integer numMatches "-1 is an error, 0 means no match, else returns a number 1..maxMatches";
  output String matchedSubstrings[maxMatches] "unmatched strings are returned as empty";
external "C" numMatches = OpenModelica_regex(str,re,maxMatches,extended,caseInsensitive,matchedSubstrings);
annotation(preferredView="text");
end regex;

function regexBool "Returns true if the string matches the regular expression."
  input String str;
  input String re;
  input Boolean extended := true "Use POSIX extended or regular syntax";
  input Boolean caseInsensitive := false;
  output Boolean matches;
protected
  Integer numMatches;
algorithm
  numMatches := regex(str,re,0,extended,caseInsensitive);
  matches := numMatches == 1;
annotation(preferredView="text");
end regexBool;

function testsuiteFriendlyName
  input String path;
  output String fixed;
protected
  Integer i;
  String matches[4];
algorithm
  (i,matches) := regex(path, "^(.*/testsuite/)?(.*/build/)?(.*)",4);
  fixed := matches[i];
end testsuiteFriendlyName;

function readFileNoNumeric
  "Returns the contents of the file, with anything resembling a (real) number stripped out, and at the end adding:
  Filter count from number domain: n.
  This should probably be changed to multiple outputs; the filtered string and an integer.
  Does anyone use this API call?"
  input String fileName;
  output String contents;
external "builtin";
annotation(preferredView="text");
end readFileNoNumeric;

function getErrorString "Returns the current error message. [file.mo:n:n-n:n:b] Error: message"
  input Boolean warningsAsErrors := false;
  output String errorString;
external "builtin";
annotation(preferredView="text", Documentation(info="<html>
<p>Returns a user-friendly string containing the errors stored in the buffer. With warningsAsErrors=true, it reports warnings as if they were errors.</p>
</html>"));
end getErrorString;

function getMessagesString
  "see getErrorString()"
  output String messagesString;
external "builtin" messagesString=getErrorString();
annotation(preferredView="text");
end getMessagesString;

record SourceInfo
  String filename;
  Boolean readonly;
  Integer lineStart;
  Integer columnStart;
  Integer lineEnd;
  Integer columnEnd;
annotation(preferredView="text");
end SourceInfo;

type ErrorKind = enumeration(
  syntax "syntax errors",
  grammar "grammatical errors",
  translation "instantiation errors: up to flat modelica",
  symbolic "symbolic manipulation error, simcodegen, up to executable file",
  runtime "simulation/function runtime error",
  scripting "runtime scripting /interpretation error"
);
type ErrorLevel = enumeration(notification,warning,error);

record ErrorMessage
  SourceInfo info;
  String message "After applying the individual arguments";
  ErrorKind kind;
  ErrorLevel level;
  Integer id "Internal ID of the error (just ignore this)";
annotation(preferredView="text");
end ErrorMessage;

function getMessagesStringInternal
  "{{[file.mo:n:n-n:n:b] Error: message, TRANSLATION, Error, code}}
  if unique = true (the default) only unique messages will be shown"
  input Boolean unique := true;
  output ErrorMessage[:] messagesString;
external "builtin";
annotation(preferredView="text");
end getMessagesStringInternal;

function countMessages
  output Integer numMessages;
  output Integer numErrors;
  output Integer numWarnings;
external "builtin"
annotation(Documentation(info="<html>
<p>Returns the total number of messages in the error buffer, as well as the number of errors and warnings.</p>
</html>"));
end countMessages;

function clearMessages "Clears the error buffer."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end clearMessages;

function runScript "Runs the mos-script specified by the filename."
  input String fileName "*.mos";
  output String result;
external "builtin";
annotation(preferredView="text");
end runScript;

function echo "echo(false) disables Interactive output, echo(true) enables it again."
  input Boolean setEcho;
  output Boolean newEcho;
external "builtin";
annotation(preferredView="text");
end echo;

function getClassesInModelicaPath "MathCore-specific or not? Who knows!"
  output String classesInModelicaPath;
external "builtin";
annotation(preferredView="text");
end getClassesInModelicaPath;

/* These don't influence anything...
function getClassNamesForSimulation
  output String classNamesForSimulation;
external "builtin";
end getClassNamesForSimulation;

function setClassNamesForSimulation
  input String classNamesForSimulation;
  output Boolean success;
external "builtin";
end setClassNamesForSimulation;
*/

function getAnnotationVersion "Returns the current annotation version."
  output String annotationVersion;
external "builtin";
annotation(preferredView="text");
end getAnnotationVersion;

function setAnnotationVersion "Sets the annotation version."
  input String annotationVersion;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+annotationVersion=" + annotationVersion);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setAnnotationVersion;

function getNoSimplify "Returns true if noSimplify flag is set."
  output Boolean noSimplify;
external "builtin";
annotation(preferredView="text");
end getNoSimplify;

function setNoSimplify "Sets the noSimplify flag."
  input Boolean noSimplify;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setNoSimplify;

function getVectorizationLimit
  output Integer vectorizationLimit;
external "builtin";
annotation(preferredView="text");
end getVectorizationLimit;

function setVectorizationLimit
  input Integer vectorizationLimit;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+v=" + String(vectorizationLimit));
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setVectorizationLimit;

public function getDefaultOpenCLDevice
  "Returns the id for the default OpenCL device to be used."
  output Integer defdevid;
external "builtin";
annotation(preferredView="text");
end getDefaultOpenCLDevice;

public function setDefaultOpenCLDevice
  "Sets the default OpenCL device to be used."
  input Integer defdevid;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+o=" + String(defdevid));
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setDefaultOpenCLDevice;

function setShowAnnotations
  input Boolean show;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setShowAnnotations;

function getShowAnnotations
  output Boolean show;
external "builtin";
annotation(preferredView="text");
end getShowAnnotations;

function setOrderConnections "Sets the orderConnection flag."
  input Boolean orderConnections;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+orderConnections=" + String(orderConnections));
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setOrderConnections;

function getOrderConnections "Returns true if orderConnections flag is set."
  output Boolean orderConnections;
external "builtin";
annotation(preferredView="text");
end getOrderConnections;

function setLanguageStandard "Sets the Modelica Language Standard."
  input String inVersion;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+std=" + inVersion);
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setLanguageStandard;

function getLanguageStandard "Returns the current Modelica Language Standard in use."
  output String outVersion;
external "builtin";
annotation(preferredView="text");
end getLanguageStandard;

function getAstAsCorbaString "Print the whole AST on the CORBA format for records, e.g.
  record Absyn.PROGRAM
    classes = ...,
    within_ = ...,
    globalBuildTimes = ...
  end Absyn.PROGRAM;"
  input String fileName := "<interactive>";
  output String result "returns the string if fileName is interactive; else it returns ok or error depending on if writing the file succeeded";
external "builtin";
annotation(preferredView="text");
end getAstAsCorbaString;

function cd "change directory to the given path (which may be either relative or absolute)
  returns the new working directory on success or a message on failure
  if the given path is the empty string, the function simply returns the current working directory."
  input String newWorkingDirectory := "";
  output String workingDirectory;
external "builtin";
annotation(preferredView="text");
end cd;

function mkdir "create directory of given path (which may be either relative or absolute)
  returns true if directory was created or already exists."
  input String newDirectory;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end mkdir;

function remove "removes a file or directory of given path (which may be either relative or absolute)
  returns 0 if path was removed successfully."
  input String newDirectory;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end remove;

function checkModel "Checks a model and returns number of variables and equations."
  input TypeName className;
  output String result;
external "builtin";
annotation(preferredView="text");
end checkModel;

function checkAllModelsRecursive "Checks all models recursively and returns number of variables and equations."
  input TypeName className;
  input Boolean checkProtected := false "Checks also protected classes if true";
  output String result;
external "builtin";
annotation(preferredView="text");
end checkAllModelsRecursive;

function typeOf
  input VariableName variableName;
  output String result;
external "builtin";
annotation(preferredView="text");
end typeOf;

function instantiateModel "Instantiates the class and returns the flat Modelica code."
  input TypeName className;
  output String result;
external "builtin";
annotation(preferredView="text");
end instantiateModel;

function buildOpenTURNSInterface "generates wrapper code for OpenTURNS"
  input TypeName className;
  input String pythonTemplateFile;
  input Boolean showFlatModelica := false;
  output String outPythonScript;
  external "builtin";
end buildOpenTURNSInterface;

function runOpenTURNSPythonScript "runs OpenTURNS with the given python script returning the log file"
  input String pythonScriptFile;
  output String logOutputFile;
  external "builtin";
end runOpenTURNSPythonScript;

function generateCode "The input is a function name for which C-code is generated and compiled into a dll/so"
  input TypeName className;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end generateCode;

function loadModel "Loads the Modelica Standard Library."
  input TypeName className;
  input String[:] priorityVersion := {"default"};
  input Boolean notify := false "Give a notification of the libraries and versions that were loaded";
  input String languageStandard := "" "Override the set language standard. Parse with the given setting, but do not change it permanently.";
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html>
Loads a Modelica library.
<h4>Syntax</h4>
<blockquote>
<pre><b>loadModel</b>(Modelica)</pre>
<pre><b>loadModel</b>(Modelica,{\"3.2\"})</pre>
</blockquote>
<h4>Description</h4>
<p>loadModel() begins by parsing the <a href=\"modelica://OpenModelica.Scripting.getModelicaPath\">getModelicaPath()</a>, and looking for candidate packages to load in the given paths (separated by : or ; depending on OS).</p>
<p>The candidate is selected by choosing the one with the highest priority, chosen by looking through the <i>priorityVersion</i> argument to the function.
If the version searched for is \"default\", the following special priority is used: no version name > highest main release > highest pre-release > lexical sort of others (see table below for examples).
If none of the searched versions exist, false is returned and an error is added to the buffer.</p>
<p>A top-level package may either be defined in a file (\"Modelica 3.2.mo\") or directory (\"Modelica 3.2/package.mo\")</p>
<p>The encoding of any Modelica file in the package is assumed to be UTF-8.
Legacy code may contain files in a different encoding.
In order to handle this, add a file package.encoding at the top-level of the package, containing a single line with the name of the encoding in it.
If your package contains files with mixed encodings and your system iconv supports UTF-8//IGNORE, you can ignore the bad characters in some of the files.
You are recommended to convert your files to UTF-8 without byte-order mark.
</p>

<table summary=\"Modelica version numbering\">
<tr><th>Priority</th><th>Example</th></tr>
<tr><td>No version name</td><td>Modelica</td></tr>
<tr><td>Main release</td><td>Modelica 3.3</td></tr>
<tr><td>Pre-release</td><td>Modelica 3.3 Beta 1</td></tr>
<tr><td>Non-ordered</td><td>Modelica Trunk</td></tr>
</table>

<h4>Bugs</h4>
<p>If loadModel(Modelica.XXX) is called, loadModel(Modelica) is executed instead, loading the complete library.</p>
</html>"),
preferredView="text");
end loadModel;

function deleteFile "Deletes a file with the given name."
  input String fileName;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end deleteFile;

function saveModel
  input String fileName;
  input TypeName className;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end saveModel;

function saveTotalModel
  input String fileName;
  input TypeName className;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end saveTotalModel;

function save
  input TypeName className;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end save;

function saveTotalSCode = saveTotalModel;

function translateGraphics
  input TypeName className;
  output String result;
external "builtin";
annotation(preferredView="text");
end translateGraphics;

function codeToString
  input $Code className;
  output String string;
external "builtin";
annotation(preferredView="text");
end codeToString;

function dumpXMLDAE "Outputs the DAE system corresponding to a specific model."
  input TypeName className;
  input String translationLevel := "flat" "flat, optimiser, backEnd, or stateSpace";
  input Boolean addOriginalIncidenceMatrix := false;
  input Boolean addSolvingInfo := false;
  input Boolean addMathMLCode := false;
  input Boolean dumpResiduals := false;
  input String fileNamePrefix := "<default>" "this is the className in string form by default";
  input String rewriteRulesFile := "" "the file from where the rewiteRules are read, default is empty which means no rewrite rules";
  output Boolean success "if the function succeeded true/false";
  output String xmlfileName "the Xml file";
external "builtin";
annotation(Documentation(info="<html>
<p>Valid translationLevel strings are: <em>flat</em>, <em>optimiser</em> (runs the backend until sorting/matching), <em>backEnd</em>, or <em>stateSpace</em>.</p>
</html>"),preferredView="text");
end dumpXMLDAE;

function convertUnits
  input String s1;
  input String s2;
  output Boolean unitsCompatible;
  output Real scaleFactor1;
  output Real offset1;
  output Real scaleFactor2;
  output Real offset2;
external "builtin";
annotation(preferredView="text",Documentation(info="<html>
<p>Returns the scale factor and offsets used when converting two units.</p>
<p>Returns false if the types are not compatible and should not be converted.</p>
</html>"));
end convertUnits;

function listVariables "Lists the names of the active variables in the scripting environment."
  output TypeName variables[:];
external "builtin";
annotation(preferredView="text");
end listVariables;

function strtok "Splits the strings at the places given by the token, for example:
  strtok(\"abcbdef\",\"b\") => {\"a\",\"c\",\"def\"}
  strtok(\"abcbdef\",\"cd\") => {\"ab\",\"ef\"}
"
  input String string;
  input String token;
  output String[:] strings;
external "builtin";
annotation(preferredView="text");
end strtok;

public function stringReplace
  input String str;
  input String source;
  input String target;
  output String res;
external "builtin";
annotation(Documentation(info="<html>
Replaces all occurances of the string <em>source</em> with <em>target</em>.
</html>"),preferredView="text");
end stringReplace;

public function escapeXML
  input String inStr;
  output String outStr;
algorithm
  outStr := stringReplace(inStr, "&", "&amp;");
  outStr := stringReplace(outStr, "<", "&lt;");
  outStr := stringReplace(outStr, ">", "&gt;");
  outStr := stringReplace(outStr, "\"", "&quot;");
end escapeXML;

type ExportKind = enumeration(Absyn "Normal Absyn",SCode "Normal SCode",MetaModelicaInterface "A restricted MetaModelica package interface (protected parts are stripped)",Internal "True unparsing of the Absyn");

function list "Lists the contents of the given class, or all loaded classes."
  input TypeName class_ := $TypeName(AllLoadedClasses);
  input Boolean interfaceOnly := false;
  input Boolean shortOnly := false "only short class definitions";
  input ExportKind exportKind := ExportKind.Absyn;
  output String contents;
external "builtin";
annotation(Documentation(info="<html>
Pretty-prints a class definition.
<h4>Syntax</h4>
<blockquote>
<pre><b>list</b>(Modelica.Math.sin)</pre>
<pre><b>list</b>(Modelica.Math.sin,interfaceOnly=true)</pre>
</blockquote>
<h4>Description</h4>
<p>list() pretty-prints the whole of the loaded AST while list(className) lists a class and its children.
It keeps all annotations and comments intact but strips out any comments and normalizes white-space.</p>
<p>list(className,interfaceOnly=true) works on functions and pretty-prints only the interface parts
(annotations and protected sections removed). String-comments on public variables are kept.</p>
<p>If the specified class does not exist (or is not a function when interfaceOnly is given), the
empty string is returned.</p>
</html>",revisions="<html>
<table>
<tr><th>Revision</th><th>Author</th><th>Comment</th></tr>
<tr><td>16124</td><td>sjoelund.se</td><td>Added replaced exportAsCode option with exportKind (selecting which kind of unparsing to use)</td></tr>
<tr><td>10796</td><td>sjoelund.se</td><td>Added shortOnly option</td></tr>
<tr><td>10756</td><td>sjoelund.se</td><td>Added interfaceOnly option</td></tr>
</table>
</html>"),
  preferredView="text");
end list;

// exportToFigaro added by Alexander Carlqvist
function exportToFigaro
  input TypeName path;
  input String database;
  input String mode;
  input String options;
  input String processor;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end exportToFigaro;

public function rewriteBlockCall "Function for property modeling, transforms block calls into instantiations for a loaded model"
  input TypeName className;
  input TypeName inDefs;
  output Boolean success;
external "builtin";
annotation(Documentation(info="<html>
<p>An extension for modeling requirements in Modelica. Rewrites block calls as block instantiations.</p>
</html>"),preferredView="text");
end rewriteBlockCall;

function realpath "Get full path name of file or directory name"
  input String name "Absolute or relative file or directory name";
  output String fullName "Full path of 'name'";
external "C" fullName = ModelicaInternal_fullPathName(name) annotation(Library="ModelicaExternalC");
  annotation (Documentation(info="<html>
Return the canonicalized absolute pathname.
Similar to <a href=\"http://linux.die.net/man/3/realpath\">realpath(3)</a>, but with the safety of Modelica strings.
</html>"));
end realpath;

function uriToFilename
  input String uri;
  output String filename := "";
  output String message := "";
protected
  String [:,2] libraries;
  Integer numMatches;
  String [:] matches,matches2;
  String path, schema, str;
  Boolean isUri,isMatch:=false,isModelicaUri,isFileUri,isFileUriAbsolute;
algorithm
  isUri := regexBool(uri, "^[A-Za-z]*://");
  if isUri then
    (numMatches,matches) := regex(uri,"^[A-Za-z]*://?([^/]*)(.*)$",4);
    isModelicaUri := regexBool(uri, "^modelica://", caseInsensitive=true);
    isFileUriAbsolute := regexBool(uri, "^file:///", caseInsensitive=true);
    isFileUri := regexBool(uri, "^file://", caseInsensitive=true);
    if isModelicaUri then
      libraries := getLoadedLibraries();
      if sum(1 for lib in libraries) == 0 then
        filename := "";
        return;
      end if;
      path := matches[2];
      if path == "" then
        message := "Malformed modelica:// URI path. Package name '" + matches[2]+"', path: '"+matches[3] + "'";
        return;
      end if;
      while path <> "" loop
        (numMatches,matches2) := regex(path, "^([A-Za-z_][A-Za-z0-9_]*)?[.]?(.*)?$",3);
        path := matches2[3];
        if isMatch then
          /* We already have a match for the first part. The full name was e.g. Modelica.Blocks, so we now see if the Blocks directory exists, and so on */
          if directoryExists(filename + "/" + matches2[2]) then
            filename := realpath(filename + "/" + matches2[2]);
          else
            break;
          end if;
        else
          /* It is the first part of the name (Modelica.XXX) - look among the loaded classes for the name Modelica and use that path */
          for i in 1:sum(1 for lib in libraries) loop
            if libraries[i,1] == matches2[2] then
              filename := libraries[i,2];
              isMatch := true;
              break;
            end if;
          end for;
          if not isMatch then
            message := "Could not resolve URI: " + uri;
            filename := "";
            return;
          end if;
        end if;
      end while;
      filename := if isMatch then filename + matches[3] else filename;
    elseif isFileUriAbsolute then
      (,matches) := regex(uri,"file://(/.*)?",2,caseInsensitive=true);
      filename := matches[2];
    elseif isFileUri and not isFileUriAbsolute then
      (,matches) := regex(uri,"file://(.*)",2,caseInsensitive=true);
      filename := realpath("./") + "/" + matches[2];
      return;
    elseif not (isModelicaUri or isFileUri) then
      /* Not using else because OpenModelica handling of assertions at runtime is not very good */
      message := "Unknown URI schema: " + uri;
      filename := "";
      return;
    else
      /* empty */
      message := "Unknown error";
      filename := "";
    end if;
  else
    filename := if regularFileExists(uri) then realpath(uri) else if regexBool(uri, "^/") then uri else (realpath("./") + "/" + uri);
  end if;
annotation(Documentation(info="<html>
Handles modelica:// and file:// URI's. The result is an absolute path on the local system.
modelica:// URI's are only handled if the class is already loaded.
Returns the empty string on failure.
</html>"));
end uriToFilename;

function getLoadedLibraries
  output String [:,2] libraries;
external "builtin";
annotation(Documentation(info="<html>
Returns a list of names of libraries and their path on the system, for example:
<pre>{{\"Modelica\",\"/usr/lib/omlibrary/Modelica 3.2.1\"},{\"ModelicaServices\",\"/usr/lib/omlibrary/ModelicaServices 3.2.1\"}}</pre>
</html>"));
end getLoadedLibraries;

type LinearSystemSolver = enumeration(dgesv,lpsolve55);
function solveLinearSystem
  "Solve A*X = B, using dgesv or lp_solve (if any variable in X is integer)
  Returns for solver dgesv: info>0: Singular for element i. info<0: Bad input.
  For solver lp_solve: ???"
  input Real[size(B,1),size(B,1)] A;
  input Real[:] B;
  input LinearSystemSolver solver := LinearSystemSolver.dgesv;
  input Integer[:] isInt := {-1} "list of indices that are integers";
  output Real[size(B,1)] X;
  output Integer info;
external "builtin";
annotation(preferredView="text");
end solveLinearSystem;

type StandardStream = enumeration(stdin,stdout,stderr);
function reopenStandardStream
  input StandardStream _stream;
  input String filename;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end reopenStandardStream;

function importFMU "Imports the Functional Mockup Unit
  Example command:
  importFMU(\"A.fmu\");"
  input String filename "the fmu file name";
  input String workdir := "<default>" "The output directory for imported FMU files. <default> will put the files to current working directory.";
  input Integer loglevel := 3 "loglevel_nothing=0;loglevel_fatal=1;loglevel_error=2;loglevel_warning=3;loglevel_info=4;loglevel_verbose=5;loglevel_debug=6";
  input Boolean fullPath := false "When true the full output path is returned otherwise only the file name.";
  input Boolean debugLogging := false "When true the FMU's debug output is printed.";
  input Boolean generateInputConnectors := true "When true creates the input connector pins.";
  input Boolean generateOutputConnectors := true "When true creates the output connector pins.";
  output String generatedFileName "Returns the full path of the generated file.";
external "builtin";
annotation(preferredView="text");
end importFMU;

function translateModelFMU
"translates a modelica model into a Functional Mockup Unit.
The only required argument is the className, while all others have some default values.
  Example command:
  translateModelFMU(className, version=\"2.0\");"
  input TypeName className "the class that should translated";
  input String version := "1.0" "The output directory for imported FMU files. <default> will put the files to current working directory.";
  input String fileNamePrefix := "<default>" "fileNamePrefix. <default> = \"className\"";
  output String generatedFileName "Returns the full path of the generated FMU.";
external "builtin";
annotation(preferredView="text");
end translateModelFMU;

function simulate "simulates a modelica model by generating c code, build it and run the simulation executable.
 The only required argument is the className, while all others have some default values.
 simulate(className, [startTime], [stopTime], [numberOfIntervals], [stepSize], [tolerance], [method], [fileNamePrefix], [options], [outputFormat], [variableFilter], [measureTime], [cflags], [simflags])
 Example command:
  simulate(A);
"
  input TypeName className "the class that should simulated";
  input Real startTime := "<default>" "the start time of the simulation. <default> = 0.0";
  input Real stopTime := 1.0 "the stop time of the simulation. <default> = 1.0";
  input Real numberOfIntervals := 500 "number of intervals in the result file. <default> = 500";
  input Real tolerance := 1e-6 "tolerance used by the integration method. <default> = 1e-6";
  input String method := "<default>" "integration method used for simulation. <default> = dassl";
  input String fileNamePrefix := "<default>" "fileNamePrefix. <default> = \"\"";
  input String options := "<default>" "options. <default> = \"\"";
  input String outputFormat := "mat" "Format for the result file. <default> = \"mat\"";
  input String variableFilter := ".*" "Filter for variables that should store in result file. <default> = \".*\"";
  input String cflags := "<default>" "cflags. <default> = \"\"";
  input String simflags := "<default>" "simflags. <default> = \"\"";
  output String simulationResults;
external "builtin";
annotation(preferredView="text");
end simulate;

function buildModel "builds a modelica model by generating c code and build it.
 It does not run the code!
 The only required argument is the className, while all others have some default values.
 simulate(className, [startTime], [stopTime], [numberOfIntervals], [stepSize], [tolerance], [method], [fileNamePrefix], [options], [outputFormat], [variableFilter], [measureTime], [cflags], [simflags])
 Example command:
  simulate(A);
"
  input TypeName className "the class that should be built";
  input Real startTime := "<default>" "the start time of the simulation. <default> = 0.0";
  input Real stopTime := 1.0 "the stop time of the simulation. <default> = 1.0";
  input Real numberOfIntervals := 500 "number of intervals in the result file. <default> = 500";
  input Real tolerance := 1e-6 "tolerance used by the integration method. <default> = 1e-6";
  input String method := "<default>" "integration method used for simulation. <default> = dassl";
  input String fileNamePrefix := "<default>" "fileNamePrefix. <default> = \"\"";
  input String options := "<default>" "options. <default> = \"\"";
  input String outputFormat := "mat" "Format for the result file. <default> = \"mat\"";
  input String variableFilter := ".*" "Filter for variables that should store in result file. <default> = \".*\"";
  input String cflags := "<default>" "cflags. <default> = \"\"";
  input String simflags := "<default>" "simflags. <default> = \"\"";
  output String[2] buildModelResults;
external "builtin";
annotation(preferredView="text");
end buildModel;

function moveClass
"moves a class up or down depending on the given direction,
 it returns true if the move was performed or false if we
 could not move the class"
 input TypeName className "the class that should be moved";
 input String direction "up or down";
 output Boolean result;
external "builtin";
annotation(preferredView="text");
end moveClass;

function copyClass
"Copies a class within the same level"
 input TypeName className "the class that should be copied";
 input String newClassName "the name for new class";
 input TypeName withIn := $TypeName(TopLevel) "the with in path for new class";
 output Boolean result;
external "builtin";
annotation(preferredView="text");
end copyClass;

function linearize "creates a model with symbolic linearization matrixes"
  input TypeName className "the class that should simulated";
  input Real startTime := "<default>" "the start time of the simulation. <default> = 0.0";
  input Real stopTime := 1.0 "the stop time of the simulation. <default> = 1.0";
  input Real numberOfIntervals := 500 "number of intervals in the result file. <default> = 500";
  input Real stepSize := 0.002 "step size that is used for the result file. <default> = 0.002";
  input Real tolerance := 1e-6 "tolerance used by the integration method. <default> = 1e-6";
  input String method := "<default>" "integration method used for simulation. <default> = dassl";
  input String fileNamePrefix := "<default>" "fileNamePrefix. <default> = \"\"";
  input Boolean storeInTemp := false "storeInTemp. <default> = false";
  input Boolean noClean := false "noClean. <default> = false";
  input String options := "<default>" "options. <default> = \"\"";
  input String outputFormat := "mat" "Format for the result file. <default> = \"mat\"";
  input String variableFilter := ".*" "Filter for variables that should store in result file. <default> = \".*\"";
  input String cflags := "<default>" "cflags. <default> = \"\"";
  input String simflags := "<default>" "simflags. <default> = \"\"";
  output String linearizationResult;
external "builtin";
annotation(Documentation(info="<html>
<p>Creates a model with symbolic linearization matrixes.</p>
<p>At stopTime the linearization matrixes are evaluated and a modelica model is created.</p>
<p>The only required argument is the className, while all others have some default values.</p>
<h2>Usage:</h2>
<p><b>linearize</b>(<em>A</em>, stopTime=0.0);</p>
<p>Creates the file \"linear_A.mo\" that contains the linearized matrixes at stopTime.</p>
</html>", revisions="<html>
<table>
<tr><th>Revision</th><th>Author</th><th>Comment</th></tr>
<tr><td>13421</td><td>wbraun</td><td>Added to omc</td></tr>
</table>
</html>"),preferredView="text");
end linearize;

function optimize "optimize a modelica/optimica model by generating c code, build it and run the optimization executable.
 The only required argument is the className, while all others have some default values.
 simulate(className, [startTime], [stopTime], [numberOfIntervals], [stepSize], [tolerance], [fileNamePrefix], [options], [outputFormat], [variableFilter], [measureTime], [cflags], [simflags])
 Example command:
  simulate(A);"
  input TypeName className "the class that should simulated";
  input Real startTime := "<default>" "the start time of the simulation. <default> = 0.0";
  input Real stopTime := 1.0 "the stop time of the simulation. <default> = 1.0";
  input Real numberOfIntervals := 500 "number of intervals in the result file. <default> = 500";
  input Real stepSize := 0.002 "step size that is used for the result file. <default> = 0.002";
  input Real tolerance := 1e-6 "tolerance used by the integration method. <default> = 1e-6";
  input String method := DAE.SCONST("optimization") "optimize a modelica/optimica model.";
  input String fileNamePrefix := "<default>" "fileNamePrefix. <default> = \"\"";
  input Boolean storeInTemp := false "storeInTemp. <default> = false";
  input Boolean noClean := false "noClean. <default> = false";
  input String options := "<default>" "options. <default> = \"\"";
  input String outputFormat := "mat" "Format for the result file. <default> = \"mat\"";
  input String variableFilter := ".*" "Filter for variables that should store in result file. <default> = \".*\"";
  input String cflags := "<default>" "cflags. <default> = \"\"";
  input String simflags := "<default>" "simflags. <default> = \"\"";
  output String optimizationResults;
external "builtin";
annotation(preferredView="text");
end optimize;

function getSourceFile "Returns the filename of the class."
  input TypeName class_;
  output String filename "empty on failure";
external "builtin";
annotation(preferredView="text");
end getSourceFile;

function setSourceFile
  input TypeName class_;
  input String filename;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setSourceFile;

function isShortDefinition "returns true if the definition is a short class definition"
  input TypeName class_;
  output Boolean isShortCls;
external "builtin";
annotation(preferredView="text");
end isShortDefinition;

function setClassComment "Sets the class comment."
  input TypeName class_;
  input String filename;
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end setClassComment;

function getClassNames "Returns the list of class names defined in the class."
  input TypeName class_ := $TypeName(AllLoadedClasses);
  input Boolean recursive := false;
  input Boolean qualified := false;
  input Boolean sort := false;
  input Boolean builtin := false "List also builtin classes if true";
  input Boolean showProtected := false "List also protected classes if true";
  output TypeName classNames[:];
external "builtin";
annotation(preferredView="text");
end getClassNames;

function getUsedClassNames "Returns the list of class names used in the total program defined by the class."
  input TypeName className;
  output TypeName classNames[:];
external "builtin";
annotation(preferredView="text");
end getUsedClassNames;

function getPackages "Returns the list of packages defined in the class."
  input TypeName class_ := $TypeName(AllLoadedClasses);
  output TypeName classNames[:];
external "builtin";
annotation(preferredView="text");
end getPackages;

function setPlotSilent "Sets the plotSilent flag."
  input Boolean silent;
  output Boolean success;
algorithm
  success := setCommandLineOptions("+plotSilent=" + String(silent));
annotation(__OpenModelica_EarlyInline = true, preferredView="text");
end setPlotSilent;

function getPlotSilent "Returns true if plotSilent flag is set."
  output Boolean plotSilent;
external "builtin";
annotation(preferredView="text");
end getPlotSilent;

partial function basePlotFunction "Extending this does not seem to work at the moment. A real shame; functions below are copy-paste and all need to be updated if the interface changes."
  input String fileName := "<default>" "The filename containing the variables. <default> will read the last simulation result";
  input String interpolation := "linear" "
    Determines if the simulation data should be interpolated to allow drawing of continuous lines in the diagram.
    \"linear\" results in linear interpolation between data points, \"constant\" keeps the value of the last known
    data point until a new one is found and \"none\" results in a diagram where only known data points are plotted."
  ;
  input String title := "Plot by OpenModelica" "This text will be used as the diagram title.";
  input Boolean legend := true "Determines whether or not the variable legend is shown.";
  input Boolean grid := true "Determines whether or not a grid is shown in the diagram.";
  input Boolean logX := false "Determines whether or not the horizontal axis is logarithmically scaled.";
  input Boolean logY := false "Determines whether or not the vertical axis is logarithmically scaled.";
  input String xLabel := "time" "This text will be used as the horizontal label in the diagram.";
  input String yLabel := "" "This text will be used as the vertical label in the diagram.";
  input Boolean points := false "Determines whether or not the data points should be indicated by a dot in the diagram.";
  input Real xRange[2] := {0.0,0.0} "Determines the horizontal interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real yRange[2] := {0.0,0.0} "Determines the vertical interval that is visible in the diagram. {0,0} will select a suitable range.";
  output Boolean success "Returns true on success";
annotation(preferredView="text");
end basePlotFunction;

function plot "Launches a plot window using OMPlot."
  input VariableNames vars "The variables you want to plot";
  input Boolean externalWindow := false "Opens the plot in a new plot window";
  input String fileName := "<default>" "The filename containing the variables. <default> will read the last simulation result";
  input String title := "" "This text will be used as the diagram title.";
  input String grid := "detailed" "Sets the grid for the plot i.e simple, detailed, none.";
  input Boolean logX := false "Determines whether or not the horizontal axis is logarithmically scaled.";
  input Boolean logY := false "Determines whether or not the vertical axis is logarithmically scaled.";
  input String xLabel := "time" "This text will be used as the horizontal label in the diagram.";
  input String yLabel := "" "This text will be used as the vertical label in the diagram.";
  input Real xRange[2] := {0.0,0.0} "Determines the horizontal interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real yRange[2] := {0.0,0.0} "Determines the vertical interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real curveWidth := 1.0 "Sets the width of the curve.";
  input Integer curveStyle := 1 "Sets the style of the curve. SolidLine=1, DashLine=2, DotLine=3, DashDotLine=4, DashDotDotLine=5, Sticks=6, Steps=7.";
  input String legendPosition := "top" "Sets the POSITION of the legend i.e left, right, top, bottom, none.";
  input String footer := "" "This text will be used as the diagram footer.";
  output Boolean success "Returns true on success";
  output String[:] result "Returns list i.e {\"_omc_PlotResult\",\"<fileName>\",\"<title>\",\"<legend>\",\"<grid>\",\"<PlotType>\",\"<logX>\",\"<logY>\",\"<xLabel>\",\"<yLabel>\",\"<xRange>\",\"<yRange>\",\"<curveWidth>\",\"<curveStyle>\",\"<legendPosition>\",\"<PlotVariables>\"}";
external "builtin";
annotation(preferredView="text",Documentation(info="<html>
<p>Launches a plot window using OMPlot. Returns true on success.</p>

<p>Example command sequences:</p>
<ul>
<li>simulate(A);plot({x,y,z});</li>
<li>simulate(A);plot(x, externalWindow=true);</li>
<li>simulate(A,fileNamePrefix=\"B\");simulate(C);plot(z,\"B.mat\",legend=false);</li>
</ul>
</html>"));
end plot;

function plotAll "Works in the same way as plot(), but does not accept any
  variable names as input. Instead, all variables are part of the plot window.

  Example command sequences:
  simulate(A);plotAll();
  simulate(A);plotAll(externalWindow=true);
  simulate(A,fileNamePrefix=\"B\");simulate(C);plotAll(x,\"B.mat\");"

  input Boolean externalWindow := false "Opens the plot in a new plot window";
  input String fileName := "<default>" "The filename containing the variables. <default> will read the last simulation result";
  input String title := "" "This text will be used as the diagram title.";
  input String grid := "detailed" "Sets the grid for the plot i.e simple, detailed, none.";
  input Boolean logX := false "Determines whether or not the horizontal axis is logarithmically scaled.";
  input Boolean logY := false "Determines whether or not the vertical axis is logarithmically scaled.";
  input String xLabel := "time" "This text will be used as the horizontal label in the diagram.";
  input String yLabel := "" "This text will be used as the vertical label in the diagram.";
  input Real xRange[2] := {0.0,0.0} "Determines the horizontal interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real yRange[2] := {0.0,0.0} "Determines the vertical interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real curveWidth := 1.0 "Sets the width of the curve.";
  input Integer curveStyle := 1 "Sets the style of the curve. SolidLine=1, DashLine=2, DotLine=3, DashDotLine=4, DashDotDotLine=5, Sticks=6, Steps=7.";
  input String legendPosition := "top" "Sets the POSITION of the legend i.e left, right, top, bottom, none.";
  input String footer := "" "This text will be used as the diagram footer.";
  output Boolean success "Returns true on success";
  output String[:] result "Returns list i.e {\"_omc_PlotResult\",\"<fileName>\",\"<title>\",\"<legend>\",\"<grid>\",\"<PlotType>\",\"<logX>\",\"<logY>\",\"<xLabel>\",\"<yLabel>\",\"<xRange>\",\"<yRange>\",\"<curveWidth>\",\"<curveStyle>\",\"<legendPosition>\",\"<PlotVariables>\"}";
external "builtin";
annotation(preferredView="text");
end plotAll;

function visualize "Uses the 3D visualization package, SimpleVisual.mo, to
  visualize the model. See chapter 3.4 (3D Animation) of the OpenModelica
  System Documentation for more details.
  Writes the visulizations objects into the file \"model_name.visualize\"

  Example command sequence:
  simulate(A,outputFormat=\"mat\");visualize(A);visualize(A,\"B.mat\");visualize(A,\"B.mat\", true);
  "
  input TypeName className;
  input Boolean externalWindow := false "Opens the visualize in a new window";
  input String fileName := "<default>" "The filename containing the variables. <default> will read the last simulation result";
  output Boolean success "Returns true on success";
  external "builtin";
annotation(preferredView="text");
end visualize;

function plotParametric "Launches a plotParametric window using OMPlot. Returns true on success.

  Example command sequences:
  simulate(A);plotParametric(x,y);
  simulate(A);plotParametric(x,y, externalWindow=true);
  "
  input VariableName xVariable;
  input VariableName yVariable;
  input Boolean externalWindow := false "Opens the plot in a new plot window";
  input String fileName := "<default>" "The filename containing the variables. <default> will read the last simulation result";
  input String title := "" "This text will be used as the diagram title.";
  input String grid := "detailed" "Sets the grid for the plot i.e simple, detailed, none.";
  input Boolean logX := false "Determines whether or not the horizontal axis is logarithmically scaled.";
  input Boolean logY := false "Determines whether or not the vertical axis is logarithmically scaled.";
  input String xLabel := "time" "This text will be used as the horizontal label in the diagram.";
  input String yLabel := "" "This text will be used as the vertical label in the diagram.";
  input Real xRange[2] := {0.0,0.0} "Determines the horizontal interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real yRange[2] := {0.0,0.0} "Determines the vertical interval that is visible in the diagram. {0,0} will select a suitable range.";
  input Real curveWidth := 1.0 "Sets the width of the curve.";
  input Integer curveStyle := 1 "Sets the style of the curve. SolidLine=1, DashLine=2, DotLine=3, DashDotLine=4, DashDotDotLine=5, Sticks=6, Steps=7.";
  input String legendPosition := "top" "Sets the POSITION of the legend i.e left, right, top, bottom, none.";
  input String footer := "" "This text will be used as the diagram footer.";
  output Boolean success "Returns true on success";
  output String[:] result "Returns list i.e {\"_omc_PlotResult\",\"<fileName>\",\"<title>\",\"<legend>\",\"<grid>\",\"<PlotType>\",\"<logX>\",\"<logY>\",\"<xLabel>\",\"<yLabel>\",\"<xRange>\",\"<yRange>\",\"<curveWidth>\",\"<curveStyle>\",\"<legendPosition>\",\"<PlotVariables>\"}";
external "builtin";
annotation(preferredView="text");
end plotParametric;

function readSimulationResult "Reads a result file, returning a matrix corresponding to the variables and size given."
  input String filename;
  input VariableNames variables;
  input Integer size := 0 "0=read any size... If the size is not the same as the result-file, this function fails";
  output Real result[:,:];
external "builtin";
annotation(preferredView="text");
end readSimulationResult;

function readSimulationResultSize "The number of intervals that are present in the output file."
  input String fileName;
  output Integer sz;
external "builtin";
annotation(preferredView="text");
end readSimulationResultSize;

function readSimulationResultVars "Returns the variables in the simulation file; you can use val() and plot() commands using these names."
  input String fileName;
  input Boolean readParameters = true;
  output String[:] vars;
external "builtin";
annotation(preferredView="text");
end readSimulationResultVars;

public function compareSimulationResults "compares simulation results."
  input String filename;
  input String reffilename;
  input String logfilename;
  input Real relTol := 0.01;
  input Real absTol := 0.0001;
  input String[:] vars := fill("",0);
  output String[:] result;
external "builtin";
annotation(preferredView="text");
end compareSimulationResults;

public function diffSimulationResults "compares simulation results."
  input String actualFile;
  input String expectedFile;
  input String diffPrefix;
  input Real relTol := 1e-3 "y tolerance";
  input Real relTolDiffMinMax := 1e-4 "y tolerance based on the difference between the maximum and minimum of the signal";
  input Real rangeDelta := 0.002 "x tolerance";
  input String[:] vars := fill("",0);
  input Boolean keepEqualResults := false;
  output Boolean success /* On success, resultFiles is empty. But it might be empty on failure anyway (for example if an input file does not exist) */;
  output String[:] resultFiles;
external "builtin";
annotation(Documentation(info="<html>
<p>Takes two result files and compares them. By default, all selected variables that are not equal in the two files are output to diffPrefix.varName.csv.</p>
<p>The output is the names of the variables for which files were generated.</p>
</html>"),preferredView="text");
end diffSimulationResults;

public function diffSimulationResultsHtml
  input String var;
  input String actualFile;
  input String expectedFile;
  input Real relTol := 1e-3 "y tolerance";
  input Real relTolDiffMinMax := 1e-4 "y tolerance based on the difference between the maximum and minimum of the signal";
  input Real rangeDelta := 0.002 "x tolerance";
  output String html;
external "builtin";
annotation(Documentation(info="<html>
<p>Takes two result files and compares them. By default, all selected variables that are not equal in the two files are output to diffPrefix.varName.csv.</p>
<p>The output is the names of the variables for which files were generated.</p>
</html>"),preferredView="text");
end diffSimulationResultsHtml;

public function checkTaskGraph "Checks if the given taskgraph has the same structure as the reference taskgraph and if all attributes are set correctly."
  input String filename;
  input String reffilename;
  output String[:] result;
external "builtin";
annotation(preferredView="text");
end checkTaskGraph;

public function checkCodeGraph "Checks if the given taskgraph has the same structure as the graph described in the codefile."
  input String graphfile;
  input String codefile;
  output String[:] result;
external "builtin";
annotation(preferredView="text");
end checkCodeGraph;

function val "Return the value of a variable at a given time in the simulation results"
  input VariableName var;
  input Real time;
  input String fileName := "<default>" "The contents of the currentSimulationResult variable";
  output Real valAtTime;
external "builtin";
annotation(preferredView="text",Documentation(info="<html>
<p>Return the value of a variable at a given time in the simulation results.</p>
<p>Works on the filename pointed to by the scripting variable currentSimulationResult or a given filename.</p>
<p>For parameters, any time may be given. For variables the startTime<=time<=stopTime needs to hold.</p>
<p>On error, nan (Not a Number) is returned and the error buffer contains the message.</p>
</html>"));
end val;

function closeSimulationResultFile "Closes the current simulation result file.
  Only needed by Windows. Windows cannot handle reading and writing to the same file from different processes.
  To allow OMEdit to make successful simulation again on the same file we must close the file after reading the Simulation Result Variables.
  Even OMEdit only use this API for Windows."
  output Boolean success;
external "builtin";
annotation(preferredView="text");
end closeSimulationResultFile;

function addClassAnnotation
  input TypeName class_;
  input Expression annotate;
  output Boolean bool;
external "builtin";
annotation(preferredView="text",Documentation(info="<html>
<p>Used to set annotations, like Diagrams and Icons in classes. The function is given the name of the class
and the annotation to set.</p>
<p>Usage: addClassAnnotation(Modelica, annotate = Documentation(info = \"&lt;html&gt;&lt;/html&gt;\"))</p>
</html>"));
end addClassAnnotation;

function getAlgorithmCount "Counts the number of Algorithm sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getAlgorithmCount;

function getNthAlgorithm "Returns the Nth Algorithm section."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthAlgorithm;

function getInitialAlgorithmCount "Counts the number of Initial Algorithm sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getInitialAlgorithmCount;

function getNthInitialAlgorithm "Returns the Nth Initial Algorithm section."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthInitialAlgorithm;

function getAlgorithmItemsCount "Counts the number of Algorithm items in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getAlgorithmItemsCount;

function getNthAlgorithmItem "Returns the Nth Algorithm Item."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthAlgorithmItem;

function getInitialAlgorithmItemsCount "Counts the number of Initial Algorithm items in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getInitialAlgorithmItemsCount;

function getNthInitialAlgorithmItem "Returns the Nth Initial Algorithm Item."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthInitialAlgorithmItem;

function getEquationCount "Counts the number of Equation sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getEquationCount;

function getNthEquation "Returns the Nth Equation section."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthEquation;

function getInitialEquationCount "Counts the number of Initial Equation sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getInitialEquationCount;

function getNthInitialEquation "Returns the Nth Initial Equation section."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthInitialEquation;

function getEquationItemsCount "Counts the number of Equation items in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getEquationItemsCount;

function getNthEquationItem "Returns the Nth Equation Item."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthEquationItem;

function getInitialEquationItemsCount "Counts the number of Initial Equation items in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getInitialEquationItemsCount;

function getNthInitialEquationItem "Returns the Nth Initial Equation Item."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthInitialEquationItem;

function getAnnotationCount "Counts the number of Annotation sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getAnnotationCount;

function getNthAnnotationString "Returns the Nth Annotation section as string."
  input TypeName class_;
  input Integer index;
  output String result;
external "builtin";
annotation(preferredView="text");
end getNthAnnotationString;

function getImportCount "Counts the number of Import sections in a class."
  input TypeName class_;
  output Integer count;
external "builtin";
annotation(preferredView="text");
end getImportCount;

function getNthImport "Returns the Nth Import as string."
  input TypeName class_;
  input Integer index;
  output String out[3] "{\"Path\",\"Id\",\"Kind\"}";
external "builtin";
annotation(preferredView="text");
end getNthImport;

function iconv "The iconv() function converts one multibyte characters from one character
  set to another.
  See man (3) iconv for more information.
"
  input String string;
  input String from;
  input String to := "UTF-8";
  output String result;
external "builtin";
annotation(preferredView="text");
end iconv;

function getDocumentationAnnotation "Returns the documentaiton annotation defined in the class."
  input TypeName cl;
  output String out[2] "{info,revision} TODO: Should be changed to have 2 outputs instead of an array of 2 Strings...";
external "builtin";
annotation(preferredView="text");
end getDocumentationAnnotation;

function setDocumentationAnnotation
  input TypeName class_;
  input String info = "";
  input String revisions = "";
  output Boolean bool;

  external "builtin" ;
annotation(preferredView = "text", Documentation(info = "<html>
<p>Used to set the Documentation annotation of a class. An empty argument (e.g. for revisions) means no annotation is added.</p>
</html>"));
end setDocumentationAnnotation;

function getTimeStamp
  input TypeName cl;
  output Real timeStamp;
  output String timeStampAsString;
external "builtin";
annotation(Documentation(info = "<html>
<p>The given class corresponds to a file (or a buffer), with a given last time this file was modified at the time of loading this file. The timestamp along with its String representation is returned.</p>
</html>"));
end getTimeStamp;

function stringTypeName
  input String str;
  output TypeName cl;
external "builtin";
annotation(Documentation(info = "<html>
<p>stringTypeName is used to make it simpler to create some functionality when scripting. The basic use-case is calling functions like simulate when you do not know the name of the class a priori simulate(stringTypeName(readFile(\"someFile\"))).</p>
</html>"),preferredView="text");
end stringTypeName;

function stringVariableName
  input String str;
  output VariableName cl;
external "builtin";
annotation(Documentation(info = "<html>
<p>stringVariableName is used to make it simpler to create some functionality when scripting. The basic use-case is calling functions like val when you do not know the name of the variable a priori val(stringVariableName(readFile(\"someFile\"))).</p>
</html>"),preferredView="text");
end stringVariableName;

function typeNameString
  input TypeName cl;
  output String out;
external "builtin";
annotation(preferredView="text");
end typeNameString;

function typeNameStrings
  input TypeName cl;
  output String out[:];
external "builtin";
annotation(preferredView="text");
end typeNameStrings;

function getClassComment "Returns the class comment."
  input TypeName cl;
  output String comment;
external "builtin";
annotation(preferredView="text");
end getClassComment;

function dirname
  input String path;
  output String dirname;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns the directory name of a file path.
  Similar to <a href=\"http://linux.die.net/man/3/dirname\">dirname(3)</a>, but with the safety of Modelica strings.
</html>"),
  preferredView="text");
end dirname;

function basename
  input String path;
  output String basename;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns the base name (file part) of a file path.
  Similar to <a href=\"http://linux.die.net/man/3/basename\">basename(3)</a>, but with the safety of Modelica strings.
</html>"),
  preferredView="text");
end basename;

function isPackage
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class is a package.
</html>"),
  preferredView="text");
end isPackage;

function isPartial
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class is partial.
</html>"),
  preferredView="text");
end isPartial;

function isModel
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class has restriction model.
</html>"),
  preferredView="text");
end isModel;

function isOperator
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class has restriction operator.
</html>"),
  preferredView="text");
end isOperator;

function isOperatorRecord
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class has restriction \"operator record\".
</html>"),
  preferredView="text");
end isOperatorRecord;

function isOperatorFunction
  input TypeName cl;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class has restriction \"operator function\".
</html>"),
  preferredView="text");
end isOperatorFunction;

function isProtectedClass
  input TypeName cl;
  input String c2;
  output Boolean b;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns true if the given class c1 has class c2 as one of its protected class.
</html>"),
  preferredView="text");
end isProtectedClass;

function getBuiltinType
  input TypeName cl;
  output String name;
external "builtin";
annotation(
  Documentation(info="<html>
  Returns the builtin type e.g Real, Integer, Boolean & String of the class.
</html>"),
  preferredView="text");
end getBuiltinType;

function setInitXmlStartValue
  input String fileName;
  input String variableName;
  input String startValue;
  input String outputFile;
  output Boolean success := false;
protected
  String xsltproc;
  String command;
  CheckSettingsResult settings;
algorithm
  if regularFileExists(fileName) then
    settings := checkSettings();
    xsltproc := if settings.OS == "Windows_NT" then getInstallationDirectoryPath() + "/lib/omc/libexec/xsltproc/xsltproc.exe" else "xsltproc";
    command := xsltproc + " -o " + outputFile + " --stringparam variableName " + variableName + " --stringparam variableStart " + startValue + " " +
      getInstallationDirectoryPath() + "/share/omc/scripts/replace-startValue.xsl " + fileName;
    success := 0 == system(command);
  end if;
end setInitXmlStartValue;

function ngspicetoModelica "Converts ngspice netlist to Modelica code. Modelica file is created in the same directory as netlist file."
  input String netlistfileName;
  output Boolean success := false;
protected
  String command;
algorithm
  command := "python " + getInstallationDirectoryPath() + "/share/omc/scripts/ngspicetoModelica.py " + netlistfileName;
  success := 0 == system(command);
annotation(preferredView="text");
end ngspicetoModelica;

function isExperiment "An experiment is defined as having annotation Experiment(stopTime=...)"
  input TypeName name;
  output Boolean res;
external "builtin";
end isExperiment;

function getSimulationOptions
  input TypeName name;
  input Real defaultStartTime := 0.0;
  input Real defaultStopTime := 1.0;
  input Real defaultTolerance := 1e-6;
  input Integer defaultNumberOfIntervals := 500 "May be overridden by defining defaultInterval instead";
  input Real defaultInterval := 0.0 "If = 0.0, then numberOfIntervals is used to calculate the step size";
  output Real startTime;
  output Real stopTime;
  output Real tolerance;
  output Integer numberOfIntervals;
  output Real interval;
external "builtin";
annotation(Documentation(info="<html>
<p>Returns the startTime, stopTime, tolerance, and interval based on the experiment annotation.</p>
</html>"));
end getSimulationOptions;

function classAnnotationExists "Check if annotation exists"
  input TypeName className;
  input TypeName annotationName;
  output Boolean exists;
external "builtin";
annotation(Documentation(info="<html>
Returns true if <b>className</b> has a class annotation called <b>annotationName</b>.
</html>",revisions="<html>
<table>
<tr><th>Revision</th><th>Author</th><th>Comment</th></tr>
<tr><td>16311</td><td>sjoelund.se</td><td>Added to omc</td></tr>
</table>
</html>"));
end classAnnotationExists;

function getBooleanClassAnnotation "Check if annotation exists and returns its value"
  input TypeName className;
  input TypeName annotationName;
  output Boolean value;
external "builtin";
annotation(Documentation(info="<html>
Returns the value of the class annotation <b>annotationName</b> of class <b>className</b>. If there is no such annotation, or if it is not true or false, this function fails.
</html>",revisions="<html>
<table>
<tr><th>Revision</th><th>Author</th><th>Comment</th></tr>
<tr><td>16311</td><td>sjoelund.se</td><td>Added to omc</td></tr>
</table>
</html>"));
end getBooleanClassAnnotation;

function extendsFrom "returns true if the given class extends from the given base class"
  input TypeName className;
  input TypeName baseClassName;
  output Boolean res;
external "builtin";
end extendsFrom;

function loadModelica3D
  input String version := "3.2.1";
  output Boolean status;
protected
  String m3d;
algorithm
  status := loadModel(Modelica,{version});
  if version == "3.1" then
    status := status and loadModel(ModelicaServices,{"1.0 modelica3d"});
    m3d:=getInstallationDirectoryPath()+"/lib/omlibrary-modelica3d/";
    status := status and min(loadFile({m3d + file for file in {"DoublePendulum.mo","Engine1b.mo","Internal.mo","Pendulum.mo"}}));
  elseif status then
    status := loadModel(ModelicaServices,{version + " modelica3d"});
  end if;
  annotation(Documentation(info="<html>
<h2>Usage</h2>
<p>Modelica3D requires some changes to the standard ModelicaServices in order to work correctly. These changes will make your MultiBody models unable to simulate because they need an object declared as:</p>
<pre>inner ModelicaServices.Modelica3D.Controller m3d_control</pre>
<p>Example session:</p>
<pre>loadModelica3D();getErrorString();
loadString(\"model DoublePendulum
  extends Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum;
  inner ModelicaServices.Modelica3D.Controller m3d_control;
end DoublePendulum;\");getErrorString();
simulate(DoublePendulum);</pre>
<p>This API call will load the modified ModelicaServices 3.2.1 so Modelica3D runs. You can also simply call loadModel(ModelicaServices,{\"3.2.1 modelica3d\"});</p>
<p>You will also need to start an m3d backend to render the results. We hid them in $OPENMODELICAHOME/lib/omlibrary-modelica3d/osg-gtk/dbus-server.py (or blender2.59).</p>
<p>For more information and example models, visit the <a href=\"https://mlcontrol.uebb.tu-berlin.de/redmine/projects/modelica3d-public/wiki\">Modelica3D wiki</a>.</p>
 </html>"));
end loadModelica3D;

function searchClassNames "Searches for the class name in the all the loaded classes.
  Example command:
  searchClassNames(\"ground\");
  searchClassNames(\"ground\", true);"
  input String searchText;
  input Boolean findInText := false;
  output TypeName classNames[:];
external "builtin";
annotation(
  Documentation(info="<html>
  Look for searchText in All Loaded Classes and their code. Returns the list of searched classes.
</html>"),
  preferredView="text");
end searchClassNames;

function getAvailableLibraries
  output String[:] libraries;
external "builtin";
annotation(
  Documentation(info="<html>
  Looks for all libraries that are visible from the <a href=\"modelica://OpenModelica.Scripting.getModelicaPath\">getModelicaPath()</a>.
</html>"),
  preferredView="text");
end getAvailableLibraries;

function getUses
  input TypeName pack;
  output String[:,:] uses;
external "builtin";
annotation(
  Documentation(info="<html>
Returns the libraries used by the package {{\"Library1\",\"Version\"},{\"Library2\",\"Version\"}}.
</html>"),
  preferredView="text");
end getUses;

function getDerivedClassModifierNames "Returns the derived class modifier names.
  Example command:
  type Resistance = Real(final quantity=\"Resistance\",final unit=\"Ohm\");
  getDerivedClassModifierNames(Resistance) => {\"quantity\",\"unit\"}"
  input TypeName className;
  output String[:] modifierNames;
external "builtin";
annotation(
  Documentation(info="<html>
  Finds the modifiers of the derived class.
</html>"),
  preferredView="text");
end getDerivedClassModifierNames;

function getDerivedClassModifierValue "Returns the derived class modifier value.
  Example command:
  type Resistance = Real(final quantity=\"Resistance\",final unit=\"Ohm\");
  getDerivedClassModifierValue(Resistance, unit); => \" = \"Ohm\"\"
  getDerivedClassModifierValue(Resistance, quantity); => \" = \"Resistance\"\""
  input TypeName className;
  input TypeName modifierName;
  output String modifierValue;
external "builtin";
annotation(
  Documentation(info="<html>
  Finds the modifier value of the derived class.
</html>"),
  preferredView="text");
end getDerivedClassModifierValue;

function generateEntryPoint
  input String fileName;
  input TypeName entryPoint;
  input String url = "https://trac.openmodelica.org/OpenModelica/newticket";
external "builtin";
annotation(
  Documentation(info="<html>
<p>Generates a main() function that calls the given MetaModelica entrypoint (assumed to have input list<String> and no outputs).</p>
</html>"));
end generateEntryPoint;

function numProcessors
  output Integer result;
external "builtin";
annotation(
  Documentation(info="<html>
<p>Returns the number of processors (if compiled against hwloc) or hardware threads (if using sysconf) available to OpenModelica.</p>
</html>"));
end numProcessors;

function runScriptParallel
  input String scripts[:];
  input Integer numThreads := numProcessors();
  input Boolean useThreads := false;
  output Boolean results[:];
external "builtin";
annotation(
  Documentation(info="<html>
<p>As <a href=\"modelica://OpenModelica.Scripting.runScript\">runScript</a>, but runs the commands in parallel.</p>
<p>If useThreads=false (default), the script will be run in an empty environment (same as running a new omc process) with default config flags.</p>
<p>If useThreads=true (experimental), the scripts will run in parallel in the same address space and with the same environment (which will not be updated).</p>
</html>"));
end runScriptParallel;

function exit
  input Integer status;
external "builtin";
annotation(
  Documentation(info="<html>
<p>Forces omc to quit with the given exit status.</p>
</html>"));
end exit;

function threadWorkFailed
external "builtin";
annotation(
  Documentation(info="<html>
<p>(Experimental) Exits the current (<a href=\"modelica://OpenModelica.Scripting.runScriptParallel\">worker thread</a>) signalling a failure.</p>
</html>"));
end threadWorkFailed;

function getMemorySize
  output Real memory(unit="MiB");
external "builtin";
annotation(
  Documentation(info="<html>
<p>Retrieves the physical memory size available on the system in megabytes.</p>
</html>"));
end getMemorySize;

function GC_gcollect_and_unmap
external "builtin";
annotation(
  Documentation(info="<html>
<p>Forces GC to collect and unmap memory (we use it before we start and wait for memory-intensive tasks in child processes).</p>
</html>"));
end GC_gcollect_and_unmap;

function GC_expand_hp
  input Integer size;
  output Boolean success;
external "builtin";
annotation(
  Documentation(info="<html>
<p>Forces the GC to expand the heap to accomodate more data.</p>
</html>"));
end GC_expand_hp;

function checkInterfaceOfPackages
  input TypeName cl;
  input String dependencyMatrix[:,:];
  output Boolean success;
  external "builtin";
annotation(
  Documentation(info="<html>
<p>Verifies the __OpenModelica_Interface=str annotation of all loaded packages with respect to the given main class.</p>
<p>For each row in the dependencyMatrix, the first element is the name of a dependency type. The rest of the elements are the other accepted dependency types for this one (frontend can call frontend and util, for example). Empty entries are ignored (necessary in order to have a rectangular matrix).</p>
</html>"));
end checkInterfaceOfPackages;

function sortStrings
  input String arr[:];
  output String sorted;
  external "builtin";
annotation(
  Documentation(info="<html>
<p>Sorts a string array in ascending order.</p>
</html>"));
end sortStrings;

function getClassInformation
  input TypeName cl;
  output String restriction, comment;
  output Boolean partialPrefix, finalPrefix, encapsulatedPrefix;
  output String fileName;
  output Boolean fileReadOnly;
  output Integer lineNumberStart, columnNumberStart, lineNumberEnd, columnNumberEnd;
  output String dimensions[:];
external "builtin";
annotation(
  Documentation(info="<html>
<p>Returns class information for the given class.</p>
<p>The dimensions are returned as an array of strings. The string is the textual representation of the dimension (they are not evaluated to Integers).</p>
</html>"), preferredView="text");
end getClassInformation;

function generateScriptingAPI
  input TypeName cl;
  output Boolean success;
  output String moFile;
  output String qtFile;
external "builtin";
annotation(
  Documentation(info="<html>
<p><b>Work in progress</b></p>
<p>Returns OpenModelica.Scripting API entry points for the classes that we can automatically generate entry points for.</p>
<p>The entry points are MetaModelica code calling CevalScript directly, and Qt/C++ code that calls the MetaModelica code.</p>
</html>"), preferredView="text");
end generateScriptingAPI;

end Scripting;

package UsersGuide
package ReleaseNotes
package '1.0' "Version 1.0 (r1026, 2003-10-31)"
end '1.0';
package '1.1' "Version 1.1 (r1323, 2004-10-25)"
end '1.1';
package '1.2' "Version 1.2 (r1562, 2005-03-04)"
end '1.2';
package '1.3.1' "Version 1.3.1 (r1999, 2005-12-01)"
annotation(Documentation(info="<html>
This release has several important highlights.
This is also the <em>first</em> release for which the New BSD (Berkeley) open-source license applies to the source code, including the whole compiler and run-time system. This makes is possible to use OpenModelica for both academic and commercial purposes without restrictions.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes a significantly improved OpenModelica Compiler (OMC):
<ul>
<li>Support for hybrid and discrete-event simulation (if-equations, if-expressions, when-equations;    not yet if-statements and when-statements).</li>
<li>Parsing of full Modelica 2.2</li>
<li>Improved support for external functions.</li>
<li>Vectorization of function arguments; each-modifiers, better implementation of replaceable, better handling of structural parameters, better support for vector and array operations, and many other improvements.</li>
<li>Flattening of the Modelica Block library version 1.5 (except a few models), and simulation of most of these.</li>
<li>Automatic index reduction (present also in previous release).</li>
<li>Updated User's Guide including examples of hybrid simulation and external functions.</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
An improved window-based interactive command shell, now including command completion and better editing and font size support.
<h4>OpenModelica Notebook (OMNotebook)</h4>
A free implementation of an OpenModelica notebook (OMNOtebook), for electronic books with course material, including the DrModelica interactive course material. It is possible to simulate and plot from this notebook.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
An early alpha version of the first Eclipse plug-in (called MDT for Modelica Development Tooling) for Modelica Development. This version gives compilation support and partial support for browsing Modelica package hierarchies and classes.
<h4>OpenModelica Development Environment (OMDev)</h4>
The following mechanisms have been put in place to support OpenModelica development.
<ul>
<li>Bugzilla support for OpenModelica bug tracking, accessible to anybody.</li>
<li>A system for automatic regression testing of the compiler and simulator, (+ other system parts) usually run at check in time.</li>
<li>Version handling is done using SVN, which is better than the previously used CVS system. For example, name change of modules is now possible within the version handling system.</li>
</ul>
</html>"));
end '1.3.1';
package '1.4.0' "Version 1.4.0 (r2393, 2006-05-18)"
annotation(Documentation(info="<html>
This release has a number of improvements described below. The most significant change is probably that OMC has now been translated to an extended subset of Modelica (MetaModelica), and that all development of the compiler is now done in this version..
<h4>OpenModelica Compiler (OMC)</h4>
This release includes further improvements of the OpenModelica Compiler (OMC):
<ul>
<li>Partial support for mixed system of equations.</li>
<li>New initialization routine, based on optimization (minimizing residuals of initial equations).</li>
<li>Symbolic simplification of builtin operators for vectors and matrices.</li>
<li>Improved code generation in simulation code to support e.g. Modelica functions.</li>
<li>Support for classes extending basic types, e.g. connectors (support for MSL 2.2 block connectors).</li>
<li>Support for parametric plotting via the plotParametric command.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
Essentially the same OMShell as in 1.3.1. One difference is that now all error messages are sent to the command window instead of to a separate log window.
<h4>OpenModelica Notebook (OMNotebook)</h4>
Many significant improvements and bug fixes. This version supports graphic plots within the cells in the notebook. Improved cell handling and Modelica code syntax highlighting. Command completion of the most common OMC commands is now supported. The notebook has been used in several courses.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
This is the first really useful version of MDT. Full browsing of Modelica code, e.g. the MSL 2.2, is now supported. (MetaModelica browsing is not yet fully supported). Full support for automatic indentation of Modelica code, including the MetaModelica extensions. Many bug fixes. The Eclipse plug-in is now in use for OpenModelica development at PELAB and MathCore Engineering AB since approximately one month.
<h4>OpenModelica Development Environment (OMDev)</h4>
The following mechanisms have been put in place to support OpenModelica development.
<ul>
<li>A separate web page for OMDev  (OpenModelica Development Environment).</li>
<li>A pre-packaged OMDev zip-file with precompiled binaries for development under Windows using the mingw Gnu compiler from the Eclipse MDT plug-in. (Development is also possible using Visual Studio).</li>
<li>All source code of the OpenModelica compiler has recently been translated to an extended subset of Modelica, currently called MetaModelica. The current size of OMC is approximately 100 000 lines All development is now done in this version.</li>
<li>A new tutorial and users guide for development in MetaModelica.</li>
<li>Successful builds and tests of OMC under Linux and Solaris.</li>
</ul>
</html>"));
end '1.4.0';
package '1.4.1' "Version 1.4.1 (r2432, 2006-06-19)"
annotation(Documentation(info="<html>
This release has only improvements and bug fixes of the OMC compiler, the MDT plugin and the OMDev components. The OMShell and OMNotebook are the same.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes further improvements of the OpenModelica Compiler (OMC):
<ul>
<li>Support for external objects.</li>
<li>OMC now reports the version number (via command line switches or CORBA API getVersion()).</li>
<li>Implemented caching for faster instantiation of large models.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Improvements of the error reporting when building the OMC compiler. The errors are now added to the problems view. The latest MDT release is version 0.6.6 (2006-06-06).
<h4>OpenModelica Development Environment (OMDev)</h4>
Small fixes in the MetaModelica compiler. MetaModelica Users Guide is now part of the OMDev release. The latest OMDev was release in 2006-06-06.
</html>"));
end '1.4.1';
package '1.4.2' "Version 1.4.2 (r2557, 2006-10-01)"
annotation(Documentation(info="<html>
This release has improvements and bug fixes of the OMC compiler, OMNotebook, the MDT plugin and the OMDev. OMShell is the same as previously.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes further improvements of the OpenModelica Compiler (OMC):
<ul>
<li>Improved initialization and index reduction.</li>
<li>Support for integer arrays is now largely implemented.</li>
<li>The val(variable,time) scripting function for accessing the value of a simulation result variable at a certain point in the simulated time.</li>
<li>Interactive evalution of for-loops, while-loops, if-statements, if-expressions, in the interactive scripting mode.</li>
<li>Improved documentation and examples of calling the Model Query and Manipulation API.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
Search and replace functions have been added. The DrModelica tutorial (all files) has been updated, obsolete sections removed, and models which are not supported by the current implementation marked clearly. Automatic recognition of the .onb suffix (e.g. when double-clicking) in Windows makes it even more convenient to use.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Two major improvements are added in this release:
<ul>
<li>Browsing and code completion works both for standard Modelica and for MetaModelica.</li>
<li>The debugger for algorithmic code is now available and operational in Eclipse for debugging of MetaModelica programs.</li>
</ul>
<h4>OpenModelica Development Environment (OMDev)</h4>
Mostly the same as previously.
</html>"));
end '1.4.2';
package '1.4.3' "Version 1.4.3 (r2860, 2007-07-13)"
annotation(Documentation(info="<html>
This release has  a number of significant improvements of the OMC compiler, OMNotebook, the MDT plugin and the OMDev. Increased platform availability now also for Linux and Macintosh, in addition to Windows. OMShell is the same as previously, but now ported to Linux and Mac.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes a number of  improvements of the OpenModelica Compiler (OMC):
<ul>
<li>Significantly increased compilation speed, especially with large models and many packages.</li>
<li>Now available also for Linux and Macintosh platforms.</li>
<li>Support for when-equations in algorithm sections, including elsewhen.</li>
<li>Support for inner/outer prefixes of components (but without type error checking).</li>
<li>Improved solution of nonlinear systems.</li>
<li>Added ability to compile generated simulation code using Visual Studio compiler.</li>
<li>Added smart setting of fixed attribute to false. If initial equations, OMC instead has fixed=true as default for states due to allowing overdetermined initial equation systems.</li>
<li>Better state select heuristics.</li>
<li>New function getIncidenceMatrix(ClassName) for dumping the incidence matrix.</li>
<li>Builtin functions String(), product(), ndims(), implemented.</li>
<li>Support for terminate() and assert() in equations.</li>
<li>In emitted flat form: protected variables are now prefixed with protected when printing flat class.</li>
<li>Some support for  tables, using omcTableTimeIni instead of dymTableTimeIni2.</li>
<li>Better support for empty arrays, and support for matrix operations like  a*[1,2;3,4].</li>
<li>Improved val() function can now evaluate array elements and record fields, e.g. val(x[n]), val(x.y) .</li>
<li>Support for reinit in algorithm sections.</li>
<li>String support in external functions.</li>
<li>Double precision floating point precision now also for interpreted expressions</li>
<li>Better simulation error messages.</li>
<li>Support for der(expressions).</li>
<li>Support for iterator expressions such as {3*i for i in 1..10}.</li>
<li>More test cases in the test suite.</li>
<li>A number of bug fixes, including sample and event handling bugs.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
A number of improvements, primarily in the platform availability.
<ul>
<li>Available on the Linux and Macintosh platforms, in addition to Windows.</li>
<li>Fixed cell copying bugs, plotting of derivatives now works, etc.</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
Now available also on the Macintosh platform.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
This release includes major improvements of MDT and the associated MetaModelica debugger:
<ul>
<li>Greatly improved browsing and code completion works both for standard Modelica and for MetaModelica.</li>
<li>Hovering over identifiers displays type information.</li>
<li>A new and greatly improved implementation of the debugger for MetaModelica algorithmic code, operational in Eclipse. Greatly improved performance - only approx 10% speed reduction even for 100 000 line programs. Greatly improved single stepping, step over, data structure browsing, etc.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Development Environment (OMDev)</h4>
<ul>
<li>Increased compilation speed for MetaModelica.</li>
<li>Better if-expression support in MetaModelica.</li>
</ul>
</html>"));
end '1.4.3';
package '1.4.4' "Version 1.4.4 (r3218, 2008-02-20)"
annotation(Documentation(info="<html>
This release is primarily a bug fix release, except for a preliminary version of new plotting functionality available both from the OMNotebook and separately through a Modelica API. This is also the first release under the open source license OSMC-PL (Open Source Modelica Consortium Public License), with support from the recently created Open Source Modelica Consortium. An integrated version handler, bug-, and issue tracker has also been added.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes small improvements and some bugfixes of the OpenModelica Compiler (OMC):
<ul>
<li>Better support for if-equations, also inside when.</li>
<li>Better support for calling functions in parameter expressions and interactively through dynamic loading of functions.</li>
<li>Less memory consumtion during compilation and interactive evaluation.</li>
<li>A number of bug-fixes.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
Test release of improvements, primarily in the plotting functionality and platform availability.
<ul>
<li>Preliminary version of improvements in the plotting functionality: scalable plots, zooming, logarithmic plots, grids, etc., currently available in a preliminary version through the plot2 function.</li>
<li>Programmable plotting accessible through a Modelica API.</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
Same as previously.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
This release includes minor bugfixes of MDT and the associated MetaModelica debugger.
<h4>OpenModelica Development Environment (OMDev)</h4>
Extended test suite with a better structure. Version handling, bug tracking, issue tracking, etc. now available under the integrated Codebeamer.
</html>"));
end '1.4.4';
package '1.4.5' "Version 1.4.5 (r3856, 2009-02-10)"
annotation(Documentation(info="<html>
This release has several improvements, especially platform availability, less compiler memory usage, and supporting more aspects of  Modelica 3.0.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes small improvements and some bugfixes of the OpenModelica Compiler (OMC):
<ul>
<li>Less memory consumption and better memory management over time. This also includes a better API supporting automatic memory management when calling C functions from within the compiler.</li>
<li>Modelica 3.0 parsing support.</li>
<li>Export of DAE to XML and MATLAB.</li>
<li>Support for several platforms Linux, MacOS, Windows (2000, Xp, Vista).</li>
<li>Support for record and strings as function arguments.</li>
<li>Many bug fixes.</li>
<li>(Not part of OMC): Additional free graphic editor SimForge can be used with OpenModelica.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
A number of improvements, primarily in the plotting functionality and platform availability.
<ul>
<li>A number of improvements in the plotting functionality: scalable plots, zooming, logarithmic plots, grids, etc.</li>
<li>Programmable plotting accessible through a Modelica API.</li>
<li>Simple 3D visualization.</li>
<li>Support for several platforms Linux, MacOS, Windows (2000, Xp, Vista).</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
Same as previously.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Minor bug fixes.
<h4>OpenModelica Development Environment (OMDev)</h4>
Same as previously.
</html>"));
end '1.4.5';
package '1.5.0' "Version 1.5.0 (r5856, 2010-07-13)"
annotation(Documentation(info="<html>
This OpenModelica 1.5 release has major improvements in the OpenModelica compiler frontend and some in the backend. A major improvement of this release is full flattening support for the MultiBody library as well as limited simulation support for MultiBody. Interesting new facilities are the interactive simulation and the integrated UML-Modelica modeling with ModelicaML. Approximately 4 person-years of additional effort have been invested in the compiler compared to the 1.4.5 version, e.g., in order to have a more complete coverage of Modelica 3.0, mainly focusing on improved flattening in the compiler frontend.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes major improvements of the flattening frontend part of the OpenModelica Compiler (OMC) and some improvements of the backend, including, but not restricted to:
<ul>
<li>Improved flattening speed of at least a factor of 10 or more compared to the 1.4.5 release, primarily for larger models with inner-outer, but also speedup for other models, e.g. the robot model flattens in approximately 2 seconds.</li>
<li>Flattening of all MultiBody models, including all elementary models, breaking connection graphs, world object, etc. Moreover, simulation is now possible for at least five MultiBody models: Pendulum, DoublePendulum, InitSpringConstant, World, PointGravityWithPointMasses.</li>
<li>Progress in supporting the Media library, but simulation is not yet possible.</li>
<li>Support for enumerations, both in the frontend and the backend.</li>
<li>Support for expandable connectors.</li>
<li>Support for the inline and late inline annotations in functions.</li>
<li>Complete support for record constructors, also for records containing other records.</li>
<li>Full support for iterators, including nested ones.</li>
<li>Support for inferred iterator and for-loop ranges.</li>
<li>Support for the function derivative annotation.</li>
<li>Prototype of interactive simulation.</li>
<li>Prototype of integrated UML-Modelica modeling and simulation with ModelicaML.</li>
<li>A new bidirectional external Java interface for calling external Java functions, or for calling Modelica functions from Java.</li>
<li>Complete implementation of replaceable model extends.</li>
<li>Fixed problems involving arrays of unknown dimensions.</li>
<li>Limited support for tearing.</li>
<li>Improved error handling at division by zero.</li>
<li>Support for Modelica 3.1 annotations.</li>
<li>Support for all MetaModelica language constructs inside OpenModelica.</li>
<li>OpenModelica works also under 64-bit Linux and Mac 64-bit OSX.</li>
<li>Parallel builds and running test suites in parallel on multi-core platforms.</li>
<li>New OpenModelica text template language for easier implementation of code generators, XML generators, etc.</li>
<li>New OpenModelica code generators to C and C# using the text template language.</li>
<li>Faster simulation result data file output optionally as comma-separated values.</li>
<li>Many bug fixes.</li>
</ul>
It is now possible to graphically edit models using parts from the Modelica Standard Library 3.1, since the simForge graphical editor (from Politecnico di Milano) that is used together with OpenModelica has been updated to version 0.9.0 with a important new functionality, including support for Modelica 3.1 and 3.0 annotations. The 1.6 and 2.2.1 Modelica graphical annotation versions are still supported.
<h4>OpenModelica Notebook (OMNotebook)</h4>
Improvements in platform availability.
<ul>
<li>Support for 64-bit Linux.</li>
<li>Support for Windows 7.</li>
<li>Better support for MacOS, including 64-bit OSX.</li>
</ul>
<h4>OpenModelica Shell (OMShell)</h4>
Same as previously.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Minor bug fixes.
<h4>OpenModelica Development Environment (OMDev)</h4>
Minor bug fixes.
</html>"));
end '1.5.0';
package '1.6.0' "Version 1.6.0 (r7524, 2010-12-21)"
annotation(Documentation(info="<html>
The OpenModelica 1.6 release primarily contains flattening, simulation, and performance improvements regarding Modelica Standard Library 3.1 support, but also has an interesting new tool - the OMEdit graphic connection editor, and a new educational material called DrControl, and an improved ModelicaML UML/Modelica profile with better support for modeling and requirement handling.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes bug fix and performance improvemetns of the flattening frontend part of the OpenModelica Compiler (OMC) and some improvements of the backend, including, but not restricted to:
<ul>
<li>Flattening of the whole Modelica Standard Library 3.1 (MSL 3.1), except Media and Fluid.</li>
<li>Improved flattening speed of a factor of 5-20 compared to OpenModelica 1.5 for a number of models, especially in the MultiBody library.</li>
<li>Reduced memory consumption by the OpenModelica compiler frontend, for certain large models a reduction of a factor 50.</li>
<li>Reorganized, more modular OpenModelica compiler backend, can now handle approximately 30000 equations, compared to previously approximately 10000 equations.</li>
<li>Better error messages from the compiler, especially regarding functions.</li>
<li>Improved simulation coverage of MSL 3.1. Many models that did not simulate before are now simulating. However, there are still many models in certain sublibraries that do not simulate.</li>
<li>Progress in supporting the Media library, but simulation is not yet possible.</li>
<li>Improved support for enumerations, both in the frontend and the backend.</li>
<li>Implementation of stream connectors.</li>
<li>Support for linearization through symbolic Jacobians.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
A new DrControl electronic notebook for teaching control and modeling with Modelica.
<h4>OpenModelica Shell (OMShell)</h4>
Same as previously.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Same as previously.
<h4>OpenModelica Development Environment (OMDev)</h4>
Several enhancements. Support for match-expressions in addition to matchcontinue. Support for real if-then-else. Support for if-then without else-branches. Modelica Development Tooling 0.7.7 with small improvements such as more settings, improved error detection in console, etc.
<h4>New Graphic Editor OMEdit</h4>
A new improved open source graphic model connection editor called OMEdit, supporting 3.1 graphical annotations, which makes it possible to move models back and forth to other tools without problems. The editor has been implemented by students at Linköping University and is based on the C++ Qt library.
</html>"));
end '1.6.0';
package '1.7.0' "Version 1.7.0 (r8711, 2011-04-20)"
annotation(Documentation(info="<html>
The OpenModelica 1.7 release contains OMC flattening improvements for the Media library, better and faster event handling and simulation, and fast MetaModelica support in the compiler, enabling it to compiler itself. This release also includes two interesting new tools - the OMOpttim optimization subsystem, and a new performance profiler for equation-based Modelica models.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes bug fixes and performance improvements of the flattening frontend part of the OpenModelica Compiler (OMC) and several improvements of the backend, including, but not restricted to:
<ul>
<li>Flattening of the whole Modelica Standard Library 3.1 (MSL 3.1), except Media and Fluid.</li>
<li>Progress in supporting the Media library, some models now flatten.</li>
<li>Much faster simulation of many models through more efficient handling of alias variables, binary output format, and faster event handling.</li>
<li>Faster and more stable simulation through new improved event handling, which is now default.</li>
<li>Simulation result storage in binary .mat files, and plotting from such files.</li>
<li>Support for Unicode characters in quoted Modelica identifiers, including Japanese and Chinese.</li>
<li>Preliminary MetaModelica 2.0 support. (use setCommandLineOptions({\"+g=MetaModelica\"}) ). Execution is as fast as MetaModelica 1.0, except for garbage collection.</li>
<li>Preliminary bootstrapped OpenModelica compiler: OMC now compiles itself, and the bootstrapped compiler passes the test suite. A garbage collector is still missing.</li>
<li>Many bug fixes.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
Improved much faster and more stable 2D plotting through the new OMPlot module. Plotting from binary .mat files. Better integration between OMEdit and OMNotebook, copy/paste between them.
<h4>OpenModelica Shell (OMShell)</h4>
Same as previously, except the improved 2D plotting through OMPlot.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Same as previously.
<h4>OpenModelica Development Environment (OMDev)</h4>
No changes.
<h4>Graphic Editor OMEdit</h4>
Several enhancements of OMEdit are included in this release. Support for Icon editing is now available. There is also an improved much faster 2D plotting through the new OMPlot module. Better integration between OMEdit and OMNotebook, with copy/paste between them. Interactive on-line simulation is available in an easy-to-use way.
<h4>New OMOptim Optimization Subsystem</h4>
A new optimization subsystem called OMOptim has been added to OpenModelica. Currently, parameter optimization using genetic algorithms is supported in this version 0.9. Pareto front optimization is also supported.
<h4>New Performance Profiler</h4>
A new, low overhead, performance profiler for Modelica models has been developed.
</html>"));
end '1.7.0';
package '1.8.0' "Version 1.8.0 (r10584, 2011-11-25)"
annotation(Documentation(info="<html>
The OpenModelica 1.8 release contains OMC flattening improvements for the Media library - it now flattens the whole library and simulates about 20% of its example models. Moreover, about half of the Fluid library models also flatten. This release also includes two new tool functionalities - the FMI for model exchange import and export, and a new efficient Eclipse-based debugger for Modelica/MetaModelica algorithmic code.
<h4>OpenModelica Compiler (OMC)</h4>
This release includes bug fixes and improvements of the flattening frontend part of the OpenModelica Compiler (OMC) and several improvements of the backend, including, but not restricted to:
A faster and more stable OMC model compiler. The 1.8.0 version flattens and simulates more models than the previous 1.7.0 version.
<ul>
<li>Flattening of the whole Media library, and about half of the Fluid library. Simulation of approximately 20% of the Media library example models.</li>
<li>Functional Mockup Interface FMI 1.0 for model exchange, export and import, for the Windows platform.</li>
<li>Bug fixes in the OpenModelica graphical model connection editor OMEdit, supporting easy-to-use graphical drag-and-drop modeling and MSL 3.1.</li>
<li>Bug fixes in the OMOptim optimization subsystem.</li>
<li>Beta version of compiler support for a new Eclipse-based very efficient algorithmic code debugger for functions in MetaModelica/Modelica, available in the development environment when using the bootstrapped OpenModelica compiler.</li>
<li>Improvements in initialization of simulations.</li>
<li>Improved index reduction with dynamic state selection, which improves simulation.</li>
<li>Better error messages from several parts of the compiler, including a new API call for giving better error messages.</li>
<li>Automatic partitioning of equation systems and multi-core parallel simulation of independent parts based on the shared-memory OpenMP model. This version is a preliminary experimental version without load balancing.</li>
</ul>
<h4>OpenModelica Notebook (OMNotebook)</h4>
No changes.
<h4>OpenModelica Shell (OMShell)</h4>
Small performance improvements.
<h4>OpenModelica Eclipse Plug-in (MDT)</h4>
Small fixes and improvements. MDT now also includes a beta version of a new Eclipse-based very efficient algorithmic code debugger for functions in MetaModelica/Modelica.
<h4>OpenModelica Development Environment (OMDev)</h4>
Third party binaries, including Qt libraries and executable Qt clients, are now part of the OMDev package. Also, now uses GCC 4.4.0 instead of the earlier GCC 3.4.5.
<h4>Graphic Editor OMEdit</h4>
Bug fixes. Access to FMI Import/Export through a pull-down menu. Improved configuration of library loading. A function to go to a specific line number. A button to cancel an on-going simulation. Support for some updated OMC API calls.
<h4>New OMOptim Optimization Subsystem</h4>
Bug fixes, especially in the Linux version.
<h4>FMI Support</h4>
The Functional Mockup Interface FMI 1.0 for model exchange import and export is supported by this release. The functionality is accessible via API calls as well as via pull-down menu commands in OMEdit.
</html>"));
end '1.8.0';
package '1.8.1' "Version 1.8.1 (r11645, 2012-04-03)"
annotation(Documentation(info="<html>
  <head><meta http-equiv=\"refresh\" content=\"0; url=https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.8.1\"></head>
  <body>Redirecting to the <a href=\"https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.8.1\">on-line release notes</a>.</body>
</html>"));
end '1.8.1';
package '1.9.0' "Version 1.9.0 (r17628, 2013-10-09)"
  annotation(Documentation(info = "<html>
  <head><meta http-equiv=\"refresh\" content=\"0; url=https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.9.0\"></head>
  <body>Redirecting to the <a href=\"https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.9.0\">on-line release notes</a>.</body>
</html>"));
end '1.9.0';
package '1.9.1' "Version 1.9.1 Beta 4 (2014-10-07)"
  annotation(Documentation(info = "<html>
  <head><meta http-equiv=\"refresh\" content=\"0; url=https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.9.1\"></head>
  <body>Redirecting to the <a href=\"https://trac.openmodelica.org/OpenModelica/wiki/ReleaseNotes/1.9.1\">on-line release notes</a>.</body>
</html>"));
end '1.9.1';
annotation(Documentation(info="<html>
This section summarizes the major releases of OpenModelica and what changed between the major versions.
Note that OpenModelica is developed rapidly.
The nightly builds are updated on a continuous basis and the release notes for these are not always up to date.</a>.
</html>"));
end ReleaseNotes;
end UsersGuide;

annotation(
  Documentation(revisions="<html>See <a href=\"modelica://OpenModelica.UsersGuide.ReleaseNotes\">ReleaseNotes</a></html>",
  __Dymola_DocumentationClass = true),
  preferredView="text");
end OpenModelica;
