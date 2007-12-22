<?xml version='1.0'?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:apd="http://apaged.mainia.de">
<xsl:output method="html" encoding="utf-8"/>
<xsl:template match="/apd:grammar">
	<html>
		<head>
			<title><xsl:value-of select="@name"/></title>
			<style type="text/css">
pre
{
	border: 2px solid #cccccc;
	background: #e7e7e7;
	padding: 1ex;
	margin-left: 3em;
	color: #000066;
	/*min-width: 600px;*/
}

.bnf {	/* grammar */
	background-color: #fefefe;
	color: #000066;
}
			</style>
		</head>
		<body>
			Strings in <b>bold</b> are regular expressions (lexemes).<br/>
			Lexeme lists in [ brackets ], are lexeme classes (alternation).<br/>
			<xsl:apply-templates select="apd:nt"/>
		</body>
	</html>
</xsl:template>

<xsl:template match="apd:nt">
<a name="{@name}"/>
<pre class="bnf"><i><xsl:value-of select="@name"/></i>:
<xsl:apply-templates select="apd:rule"/>
</pre>
</xsl:template>

<xsl:template match="apd:rule">
<xsl:text>    </xsl:text><xsl:apply-templates select="*"/><br/>
</xsl:template>

<xsl:template match="apd:ntref"><xsl:text> </xsl:text><a href="#{@name}"><i><xsl:value-of select="@name"/></i></a></xsl:template>

<xsl:template match="apd:altern">[<xsl:apply-templates select="*"/>]</xsl:template>

<xsl:template match="apd:terminal"><xsl:text> </xsl:text><b><xsl:value-of select="."/></b></xsl:template>

<xsl:template match="apd:epsilon"><xsl:text> </xsl:text><i>epsilon</i></xsl:template>

</xsl:stylesheet>